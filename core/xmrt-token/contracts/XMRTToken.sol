// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title XMRT Token Contract
 * @dev Implementation of the XMRT governance token with fixed supply
 * 
 * XMRT is the governance token for the XMRT DAO ecosystem
 * Total supply is fixed at 18.4 million tokens (mimicking XMR supply)
 * 
 * Features:
 * - Fixed supply with no minting capability
 * - Burnable tokens for deflationary mechanics
 * - Pausable for emergency situations
 * - EIP-2612 permit functionality for gasless approvals
 * - Governance voting capabilities
 */
contract XMRTToken is ERC20, ERC20Burnable, Pausable, Ownable, ERC20Permit {
    /// @dev Total token supply (18.4 million)
    uint256 public constant MAX_SUPPLY = 18_400_000 * (10 ** 18);
    
    /// @dev Address of the ecosystem fund
    address public immutable ECOSYSTEM_FUND;
    
    /// @dev Address of the DAO treasury
    address public immutable DAO_TREASURY;
    
    /// @dev Address for community rewards
    address public immutable COMMUNITY_REWARDS;
    
    /// @dev Allocation percentages
    uint256 public constant ECOSYSTEM_PERCENT = 35; // 35%
    uint256 public constant TREASURY_PERCENT = 25;  // 25%
    uint256 public constant COMMUNITY_PERCENT = 20; // 20%
    uint256 public constant PUBLIC_PERCENT = 20;    // 20%
    
    /// @dev Mapping to track voting power delegation
    mapping(address => address) public delegates;
    
    /// @dev Mapping to track voting power by address
    mapping(address => uint256) public votingPower;
    
    /// @dev Event emitted when voting power is delegated
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    
    /// @dev Event emitted when voting power changes
    event VotingPowerChanged(address indexed account, uint256 previousPower, uint256 newPower);
    
    /**
     * @dev Initialize token with initial allocations
     * @param _ecosystemFund Address for ecosystem fund
     * @param _daoTreasury Address for DAO treasury
     * @param _communityRewards Address for community rewards
     */
    constructor(
        address _ecosystemFund,
        address _daoTreasury,
        address _communityRewards
    ) ERC20("XMRT Token", "XMRT") ERC20Permit("XMRT Token") {
        require(_ecosystemFund != address(0), "Invalid ecosystem fund address");
        require(_daoTreasury != address(0), "Invalid DAO treasury address");
        require(_communityRewards != address(0), "Invalid community rewards address");
        
        ECOSYSTEM_FUND = _ecosystemFund;
        DAO_TREASURY = _daoTreasury;
        COMMUNITY_REWARDS = _communityRewards;
        
        // Calculate allocations
        uint256 ecosystemAllocation = MAX_SUPPLY * ECOSYSTEM_PERCENT / 100;
        uint256 treasuryAllocation = MAX_SUPPLY * TREASURY_PERCENT / 100;
        uint256 communityAllocation = MAX_SUPPLY * COMMUNITY_PERCENT / 100;
        
        // Mint initial allocations
        _mint(_ecosystemFund, ecosystemAllocation);
        _mint(_daoTreasury, treasuryAllocation);
        _mint(_communityRewards, communityAllocation);
        
        // Initialize voting power
        _updateVotingPower(_ecosystemFund, 0, ecosystemAllocation);
        _updateVotingPower(_daoTreasury, 0, treasuryAllocation);
        _updateVotingPower(_communityRewards, 0, communityAllocation);
    }
    
    /**
     * @dev Pause token transfers (emergency function)
     */
    function pause() public onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() public onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Delegate voting power to another address
     * @param delegatee Address to delegate voting power to
     */
    function delegate(address delegatee) public {
        address currentDelegate = delegates[msg.sender];
        delegates[msg.sender] = delegatee;
        
        uint256 delegatorBalance = balanceOf(msg.sender);
        
        // Update voting power
        if (currentDelegate != address(0)) {
            _updateVotingPower(currentDelegate, votingPower[currentDelegate], votingPower[currentDelegate] - delegatorBalance);
        }
        
        if (delegatee != address(0)) {
            _updateVotingPower(delegatee, votingPower[delegatee], votingPower[delegatee] + delegatorBalance);
        }
        
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
    }
    
    /**
     * @dev Get current voting power for an address
     * @param account Address to check voting power for
     * @return Current voting power
     */
    function getVotingPower(address account) public view returns (uint256) {
        return votingPower[account];
    }
    
    /**
     * @dev Override transfer to update voting power
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
        
        // Update voting power for delegated addresses
        if (from != address(0)) {
            address fromDelegate = delegates[from];
            if (fromDelegate != address(0)) {
                _updateVotingPower(fromDelegate, votingPower[fromDelegate], votingPower[fromDelegate] - amount);
            }
        }
        
        if (to != address(0)) {
            address toDelegate = delegates[to];
            if (toDelegate != address(0)) {
                _updateVotingPower(toDelegate, votingPower[toDelegate], votingPower[toDelegate] + amount);
            }
        }
    }
    
    /**
     * @dev Internal function to update voting power
     * @param account Address whose voting power is being updated
     * @param oldPower Previous voting power
     * @param newPower New voting power
     */
    function _updateVotingPower(address account, uint256 oldPower, uint256 newPower) internal {
        votingPower[account] = newPower;
        emit VotingPowerChanged(account, oldPower, newPower);
    }
    
    /**
     * @dev Get circulating supply (total supply minus burned tokens)
     * @return Current circulating supply
     */
    function circulatingSupply() public view returns (uint256) {
        return totalSupply();
    }
    
    /**
     * @dev Check if address has minimum voting power for proposals
     * @param account Address to check
     * @param minimumPower Minimum required voting power
     * @return Whether account has sufficient voting power
     */
    function hasVotingPower(address account, uint256 minimumPower) public view returns (bool) {
        return getVotingPower(account) >= minimumPower;
    }
}