// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Revenue Model for MobileMonero Transaction Fees
 * @dev Handles fee calculation and distribution for the XMRT ecosystem
 * 
 * Implements dynamic fee structure:
 * - Base fee: 0.3%
 * - Volume discounts for high-volume users
 * - Loyalty rewards for XMRT holders
 * - Automatic fee distribution to stakeholders
 */
contract RevenueModel is ReentrancyGuard, Ownable, Pausable {
    /// @dev Base fee percentage (0.3% = 30 basis points)
    uint256 public constant BASE_FEE_BPS = 30;
    
    /// @dev Volume threshold for tier 1 discount (100 ETH equivalent)
    uint256 public constant TIER1_THRESHOLD = 100 ether;
    
    /// @dev Volume threshold for tier 2 discount (1000 ETH equivalent)
    uint256 public constant TIER2_THRESHOLD = 1000 ether;
    
    /// @dev Volume threshold for tier 3 discount (10000 ETH equivalent)
    uint256 public constant TIER3_THRESHOLD = 10000 ether;
    
    /// @dev Discounted fee percentages
    uint256 public constant TIER1_FEE_BPS = 25; // 0.25%
    uint256 public constant TIER2_FEE_BPS = 20; // 0.20%
    uint256 public constant TIER3_FEE_BPS = 15; // 0.15%
    
    /// @dev XMRT token address
    IERC20 public immutable xmrtToken;
    
    /// @dev Treasury addresses
    address public immutable minerRewardPool;
    address public immutable treasuryOperations;
    address public immutable xmrtRewardPool;
    address public immutable developmentFund;
    
    /// @dev Fee distribution percentages (basis points)
    struct FeeDistribution {
        uint256 minerReward;     // 15% - Rewards for mobile miners
        uint256 treasuryOp;      // 20% - Treasury operations
        uint256 xmrtRewards;     // 50% - XMRT holder rewards
        uint256 development;     // 15% - Development fund
    }
    
    FeeDistribution public feeDistribution = FeeDistribution(1500, 2000, 5000, 1500);
    
    /// @dev User volume tracking
    mapping(address => uint256) public userVolume;
    mapping(address => uint256) public userLastActivity;
    
    /// @dev XMRT holding requirements for discounts
    uint256 public constant MIN_XMRT_FOR_DISCOUNT = 1000 * 10**18; // 1000 XMRT
    uint256 public constant XMRT_DISCOUNT_BPS = 5; // 0.05% additional discount
    
    /// @dev Volume decay parameters
    uint256 public constant VOLUME_DECAY_PERIOD = 30 days;
    uint256 public constant VOLUME_DECAY_RATE = 10; // 10% decay per period
    
    /// @dev Events
    event FeeCalculated(address indexed user, uint256 amount, uint256 fee, uint256 effectiveRate);
    event FeeDistributed(uint256 minerReward, uint256 treasuryOp, uint256 xmrtRewards, uint256 development);
    event VolumeUpdated(address indexed user, uint256 newVolume);
    event FeeDistributionUpdated(uint256 minerReward, uint256 treasuryOp, uint256 xmrtRewards, uint256 development);
    
    /**
     * @dev Initialize revenue model with distribution addresses
     * @param _xmrtToken XMRT token contract address
     * @param _minerRewardPool Address for miner rewards
     * @param _treasuryOperations Address for treasury operations
     * @param _xmrtRewardPool Address for XMRT holder rewards
     * @param _developmentFund Address for development fund
     */
    constructor(
        address _xmrtToken,
        address _minerRewardPool,
        address _treasuryOperations,
        address _xmrtRewardPool,
        address _developmentFund
    ) {
        require(_xmrtToken != address(0), "Invalid XMRT token address");
        require(_minerRewardPool != address(0), "Invalid miner reward pool address");
        require(_treasuryOperations != address(0), "Invalid treasury operations address");
        require(_xmrtRewardPool != address(0), "Invalid XMRT reward pool address");
        require(_developmentFund != address(0), "Invalid development fund address");
        
        xmrtToken = IERC20(_xmrtToken);
        minerRewardPool = _minerRewardPool;
        treasuryOperations = _treasuryOperations;
        xmrtRewardPool = _xmrtRewardPool;
        developmentFund = _developmentFund;
    }
    
    /**
     * @dev Calculate fee for a given transaction amount and user
     * @param user Address of the user making the transaction
     * @param amount Transaction amount in wei
     * @return fee Fee amount in wei
     * @return effectiveRate Effective fee rate in basis points
     */
    function calculateFee(address user, uint256 amount) public view returns (uint256 fee, uint256 effectiveRate) {
        // Get user's current volume (with decay applied)
        uint256 currentVolume = getCurrentUserVolume(user);
        
        // Determine base fee rate based on volume tier
        uint256 baseFeeRate = getVolumeTierFee(currentVolume);
        
        // Apply XMRT holder discount
        uint256 finalFeeRate = baseFeeRate;
        if (xmrtToken.balanceOf(user) >= MIN_XMRT_FOR_DISCOUNT) {
            finalFeeRate = baseFeeRate > XMRT_DISCOUNT_BPS ? baseFeeRate - XMRT_DISCOUNT_BPS : 0;
        }
        
        // Calculate fee
        fee = (amount * finalFeeRate) / 10000;
        effectiveRate = finalFeeRate;
    }
    
    /**
     * @dev Process transaction fee and update user volume
     * @param user Address of the user making the transaction
     * @param amount Transaction amount in wei
     * @return fee Fee amount collected
     */
    function processFee(address user, uint256 amount) external payable nonReentrant whenNotPaused returns (uint256 fee) {
        require(amount > 0, "Amount must be greater than 0");
        
        (uint256 calculatedFee, uint256 effectiveRate) = calculateFee(user, amount);
        require(msg.value >= calculatedFee, "Insufficient fee payment");
        
        // Update user volume
        _updateUserVolume(user, amount);
        
        // Distribute fees
        _distributeFees(calculatedFee);
        
        // Refund excess payment
        if (msg.value > calculatedFee) {
            payable(msg.sender).transfer(msg.value - calculatedFee);
        }
        
        emit FeeCalculated(user, amount, calculatedFee, effectiveRate);
        
        return calculatedFee;
    }
    
    /**
     * @dev Get fee rate based on volume tier
     * @param volume User's current volume
     * @return Fee rate in basis points
     */
    function getVolumeTierFee(uint256 volume) public pure returns (uint256) {
        if (volume >= TIER3_THRESHOLD) {
            return TIER3_FEE_BPS;
        } else if (volume >= TIER2_THRESHOLD) {
            return TIER2_FEE_BPS;
        } else if (volume >= TIER1_THRESHOLD) {
            return TIER1_FEE_BPS;
        } else {
            return BASE_FEE_BPS;
        }
    }
    
    /**
     * @dev Get user's current volume with decay applied
     * @param user Address of the user
     * @return Current volume after applying decay
     */
    function getCurrentUserVolume(address user) public view returns (uint256) {
        uint256 lastActivity = userLastActivity[user];
        if (lastActivity == 0) {
            return 0;
        }
        
        uint256 timeSinceLastActivity = block.timestamp - lastActivity;
        uint256 decayPeriods = timeSinceLastActivity / VOLUME_DECAY_PERIOD;
        
        if (decayPeriods == 0) {
            return userVolume[user];
        }
        
        // Apply exponential decay
        uint256 currentVolume = userVolume[user];
        for (uint256 i = 0; i < decayPeriods && currentVolume > 0; i++) {
            currentVolume = (currentVolume * (100 - VOLUME_DECAY_RATE)) / 100;
        }
        
        return currentVolume;
    }
    
    /**
     * @dev Internal function to update user volume
     * @param user Address of the user
     * @param amount Transaction amount to add
     */
    function _updateUserVolume(address user, uint256 amount) internal {
        uint256 currentVolume = getCurrentUserVolume(user);
        userVolume[user] = currentVolume + amount;
        userLastActivity[user] = block.timestamp;
        
        emit VolumeUpdated(user, userVolume[user]);
    }
    
    /**
     * @dev Internal function to distribute fees
     * @param totalFee Total fee amount to distribute
     */
    function _distributeFees(uint256 totalFee) internal {
        uint256 minerAmount = (totalFee * feeDistribution.minerReward) / 10000;
        uint256 treasuryAmount = (totalFee * feeDistribution.treasuryOp) / 10000;
        uint256 xmrtAmount = (totalFee * feeDistribution.xmrtRewards) / 10000;
        uint256 devAmount = (totalFee * feeDistribution.development) / 10000;
        
        // Transfer fees to respective pools
        if (minerAmount > 0) {
            payable(minerRewardPool).transfer(minerAmount);
        }
        if (treasuryAmount > 0) {
            payable(treasuryOperations).transfer(treasuryAmount);
        }
        if (xmrtAmount > 0) {
            payable(xmrtRewardPool).transfer(xmrtAmount);
        }
        if (devAmount > 0) {
            payable(developmentFund).transfer(devAmount);
        }
        
        emit FeeDistributed(minerAmount, treasuryAmount, xmrtAmount, devAmount);
    }
    
    /**
     * @dev Update fee distribution percentages (only owner)
     * @param _minerReward Miner reward percentage (basis points)
     * @param _treasuryOp Treasury operations percentage (basis points)
     * @param _xmrtRewards XMRT rewards percentage (basis points)
     * @param _development Development fund percentage (basis points)
     */
    function updateFeeDistribution(
        uint256 _minerReward,
        uint256 _treasuryOp,
        uint256 _xmrtRewards,
        uint256 _development
    ) external onlyOwner {
        require(_minerReward + _treasuryOp + _xmrtRewards + _development == 10000, "Total must equal 100%");
        
        feeDistribution = FeeDistribution(_minerReward, _treasuryOp, _xmrtRewards, _development);
        
        emit FeeDistributionUpdated(_minerReward, _treasuryOp, _xmrtRewards, _development);
    }
    
    /**
     * @dev Pause fee processing (emergency function)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause fee processing
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency withdrawal function (only owner)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
    }
}