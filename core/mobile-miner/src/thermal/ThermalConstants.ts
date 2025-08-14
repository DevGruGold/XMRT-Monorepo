/**
 * Thermal management constants for mobile mining
 * 
 * @module ThermalConstants
 */

export const ThermalConstants = {
  /** Maximum number of threads available for mining */
  MAX_THREADS: navigator.hardwareConcurrency || 4,
  
  /** Optimal operating temperature in Celsius */
  OPTIMAL_TEMP: 35.0,
  
  /** Warning temperature threshold in Celsius */
  WARNING_TEMP: 45.0,
  
  /** Critical temperature threshold in Celsius */
  CRITICAL_TEMP: 55.0,
  
  /** Emergency shutdown temperature in Celsius */
  EMERGENCY_TEMP: 65.0,
  
  /** Temperature check interval in milliseconds */
  CHECK_INTERVAL: 5000,
  
  /** Hysteresis value to prevent oscillation */
  HYSTERESIS: 2.0,
  
  /** Throttle levels and their corresponding performance multipliers */
  THROTTLE_LEVELS: {
    NONE: { level: 0, multiplier: 1.0, description: 'No throttling' },
    LIGHT: { level: 1, multiplier: 0.75, description: 'Light throttling' },
    MODERATE: { level: 2, multiplier: 0.5, description: 'Moderate throttling' },
    HEAVY: { level: 3, multiplier: 0.25, description: 'Heavy throttling' },
    CRITICAL: { level: 4, multiplier: 0.1, description: 'Critical throttling' }
  }
} as const;

export type ThrottleLevel = keyof typeof ThermalConstants.THROTTLE_LEVELS;