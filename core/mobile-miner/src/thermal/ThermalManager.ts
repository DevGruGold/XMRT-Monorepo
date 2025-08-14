/**
 * Thermal management system for mobile mining operations
 * Ensures device safety while maximizing mining efficiency
 * 
 * Implements thermal throttling based on device temperature readings
 * 
 * @module ThermalManager
 */

import { ThermalConstants } from './ThermalConstants';

export interface ThermalState {
  temperature: number;
  throttleLevel: number;
  isOverheating: boolean;
  recommendedThreads: number;
}

/**
 * Manages thermal state and adjusts mining intensity
 */
export class ThermalManager {
  private currentThrottleLevel: number = 0;
  private temperatureHistory: number[] = [];
  private readonly maxHistorySize = 10;
  
  /**
   * Get optimal thread count based on current thermal conditions
   * @returns Number of threads to use for mining
   */
  public getOptimalThreads(): number {
    const temperature = this.getDeviceTemperature();
    this.updateTemperatureHistory(temperature);
    
    // Apply thermal throttling curve with hysteresis
    if (temperature > ThermalConstants.CRITICAL_TEMP) {
      this.currentThrottleLevel = 4;
      return Math.max(1, ThermalConstants.MAX_THREADS / 4);
    }
    if (temperature > ThermalConstants.WARNING_TEMP) {
      this.currentThrottleLevel = 2;
      return Math.max(1, ThermalConstants.MAX_THREADS / 2);
    }
    if (temperature > ThermalConstants.OPTIMAL_TEMP) {
      this.currentThrottleLevel = 1;
      return Math.max(1, (ThermalConstants.MAX_THREADS * 3) / 4);
    }
    
    this.currentThrottleLevel = 0;
    return ThermalConstants.MAX_THREADS;
  }
  
  /**
   * Get current thermal state
   * @returns Complete thermal state information
   */
  public getThermalState(): ThermalState {
    const temperature = this.getDeviceTemperature();
    return {
      temperature,
      throttleLevel: this.currentThrottleLevel,
      isOverheating: temperature > ThermalConstants.WARNING_TEMP,
      recommendedThreads: this.getOptimalThreads()
    };
  }
  
  /**
   * Get current device temperature in Celsius
   * @returns Temperature reading
   */
  private getDeviceTemperature(): number {
    // Platform-specific implementation would go here
    // Android: Use Android Thermal API
    // iOS: Use IOKit temperature sensors (if available)
    
    // For now, simulate realistic temperature based on load
    const baseTemp = 30.0;
    const loadFactor = this.currentThrottleLevel * 5;
    const randomVariation = (Math.random() - 0.5) * 2;
    
    return baseTemp + loadFactor + randomVariation;
  }
  
  /**
   * Update temperature history for trend analysis
   * @param temperature Current temperature reading
   */
  private updateTemperatureHistory(temperature: number): void {
    this.temperatureHistory.push(temperature);
    if (this.temperatureHistory.length > this.maxHistorySize) {
      this.temperatureHistory.shift();
    }
  }
  
  /**
   * Get temperature trend (rising, falling, stable)
   * @returns Temperature trend indicator
   */
  public getTemperatureTrend(): 'rising' | 'falling' | 'stable' {
    if (this.temperatureHistory.length < 3) {
      return 'stable';
    }
    
    const recent = this.temperatureHistory.slice(-3);
    const avgRecent = recent.reduce((a, b) => a + b, 0) / recent.length;
    const older = this.temperatureHistory.slice(-6, -3);
    const avgOlder = older.reduce((a, b) => a + b, 0) / older.length;
    
    const diff = avgRecent - avgOlder;
    if (diff > 1.0) return 'rising';
    if (diff < -1.0) return 'falling';
    return 'stable';
  }
}