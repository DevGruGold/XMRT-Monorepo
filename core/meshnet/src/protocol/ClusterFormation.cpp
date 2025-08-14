/**
 * Cluster formation algorithm for XMRT Mesh Network
 * Creates efficient peer-to-peer clusters based on device proximity and capabilities
 * 
 * Implements battery-aware leadership election and RSSI-based proximity sorting
 */

#include "ClusterFormation.h"
#include <algorithm>
#include <cmath>
#include <chrono>
#include <random>

namespace xmrt {
namespace mesh {

/**
 * Forms a cluster with neighboring devices
 * @param devices List of detected neighboring devices
 * @param maxClusterSize Maximum number of devices in cluster
 * @return Cluster configuration with elected leader
 */
Cluster ClusterFormation::formCluster(const std::vector<Device>& devices, size_t maxClusterSize) {
    if (devices.empty()) {
        throw std::invalid_argument("Cannot form cluster with empty device list");
    }
    
    // Sort devices by signal strength (RSSI) for proximity-based clustering
    std::vector<Device> sortedDevices = devices;
    std::sort(sortedDevices.begin(), sortedDevices.end(), 
        [](const Device& a, const Device& b) {
            return a.rssi > b.rssi;
        });
    
    // Limit cluster size
    if (sortedDevices.size() > maxClusterSize) {
        sortedDevices.resize(maxClusterSize);
    }
    
    // Elect cluster leader using weighted scoring
    Device* leader = electLeader(sortedDevices);
    
    // Create cluster configuration
    Cluster cluster;
    cluster.id = generateClusterId();
    cluster.leader = leader ? *leader : sortedDevices[0];
    cluster.members.assign(sortedDevices.begin(), sortedDevices.end());
    cluster.formationTime = std::chrono::system_clock::now();
    cluster.maxSize = maxClusterSize;
    
    // Calculate cluster metrics
    cluster.averageRssi = calculateAverageRssi(cluster.members);
    cluster.totalBatteryLevel = calculateTotalBattery(cluster.members);
    
    return cluster;
}

/**
 * Elect cluster leader based on multiple criteria
 * @param devices Candidate devices for leadership
 * @return Pointer to elected leader device
 */
Device* ClusterFormation::electLeader(std::vector<Device>& devices) {
    if (devices.empty()) {
        return nullptr;
    }
    
    Device* bestCandidate = nullptr;
    double bestScore = -1.0;
    
    for (auto& device : devices) {
        double score = calculateLeadershipScore(device);
        if (score > bestScore) {
            bestScore = score;
            bestCandidate = &device;
        }
    }
    
    return bestCandidate;
}

/**
 * Calculate leadership score for a device
 * @param device Device to evaluate
 * @return Leadership score (0.0 to 1.0)
 */
double ClusterFormation::calculateLeadershipScore(const Device& device) {
    // Weighted scoring factors
    const double BATTERY_WEIGHT = 0.4;
    const double RSSI_WEIGHT = 0.3;
    const double STABILITY_WEIGHT = 0.2;
    const double CAPABILITY_WEIGHT = 0.1;
    
    // Normalize battery level (0-100 to 0-1)
    double batteryScore = device.batteryLevel / 100.0;
    
    // Normalize RSSI (-100 to 0 dBm to 0-1)
    double rssiScore = std::max(0.0, (device.rssi + 100.0) / 100.0);
    
    // Stability based on connection history
    double stabilityScore = device.connectionStability;
    
    // Capability score based on device specs
    double capabilityScore = calculateCapabilityScore(device);
    
    return (batteryScore * BATTERY_WEIGHT) +
           (rssiScore * RSSI_WEIGHT) +
           (stabilityScore * STABILITY_WEIGHT) +
           (capabilityScore * CAPABILITY_WEIGHT);
}

/**
 * Calculate device capability score
 * @param device Device to evaluate
 * @return Capability score (0.0 to 1.0)
 */
double ClusterFormation::calculateCapabilityScore(const Device& device) {
    double score = 0.0;
    
    // CPU cores (normalize to typical mobile range 1-8)
    score += std::min(1.0, device.cpuCores / 8.0) * 0.3;
    
    // RAM (normalize to typical mobile range 1-16 GB)
    score += std::min(1.0, device.ramGB / 16.0) * 0.3;
    
    // Storage (normalize to typical range 16-512 GB)
    score += std::min(1.0, device.storageGB / 512.0) * 0.2;
    
    // Network capability
    if (device.supports5G) score += 0.2;
    else if (device.supportsWiFi6) score += 0.15;
    else if (device.supportsWiFi5) score += 0.1;
    
    return std::min(1.0, score);
}

/**
 * Generate unique cluster ID
 * @return Unique cluster identifier
 */
std::string ClusterFormation::generateClusterId() {
    auto now = std::chrono::system_clock::now();
    auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();
    
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1000, 9999);
    
    return "cluster_" + std::to_string(timestamp) + "_" + std::to_string(dis(gen));
}

/**
 * Calculate average RSSI for cluster members
 * @param members Cluster member devices
 * @return Average RSSI value
 */
double ClusterFormation::calculateAverageRssi(const std::vector<Device>& members) {
    if (members.empty()) return 0.0;
    
    double sum = 0.0;
    for (const auto& device : members) {
        sum += device.rssi;
    }
    return sum / members.size();
}

/**
 * Calculate total battery level for cluster
 * @param members Cluster member devices
 * @return Total battery percentage
 */
double ClusterFormation::calculateTotalBattery(const std::vector<Device>& members) {
    double total = 0.0;
    for (const auto& device : members) {
        total += device.batteryLevel;
    }
    return total;
}

/**
 * Optimize cluster configuration
 * @param cluster Cluster to optimize
 * @return Optimized cluster configuration
 */
Cluster ClusterFormation::optimizeCluster(const Cluster& cluster) {
    Cluster optimized = cluster;
    
    // Remove devices with very low battery
    optimized.members.erase(
        std::remove_if(optimized.members.begin(), optimized.members.end(),
            [](const Device& device) {
                return device.batteryLevel < MIN_BATTERY_THRESHOLD;
            }),
        optimized.members.end()
    );
    
    // Re-elect leader if current leader was removed
    auto leaderIt = std::find_if(optimized.members.begin(), optimized.members.end(),
        [&optimized](const Device& device) {
            return device.id == optimized.leader.id;
        });
    
    if (leaderIt == optimized.members.end() && !optimized.members.empty()) {
        Device* newLeader = electLeader(optimized.members);
        if (newLeader) {
            optimized.leader = *newLeader;
        }
    }
    
    // Recalculate metrics
    optimized.averageRssi = calculateAverageRssi(optimized.members);
    optimized.totalBatteryLevel = calculateTotalBattery(optimized.members);
    
    return optimized;
}

} // namespace mesh
} // namespace xmrt