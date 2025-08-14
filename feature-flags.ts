/**
 * Feature flags for XMRT Monorepo
 * 
 * Controls which experimental features are enabled
 * Allows gradual rollout of new functionality
 */

export const FEATURE_FLAGS = {
  /**
   * Eliza AI Governance
   * 
   * Enables AI-powered proposal processing and autonomous governance
   * Currently in prototype phase - not yet connected to main ecosystem
   */
  ELIZA_GOVERNANCE: false,
  
  /**
   * Zero-Knowledge Proofs
   * 
   * Enables privacy-preserving transaction validation
   * Requires additional cryptographic libraries
   */
  ZK_PROOFS: false,
  
  /**
   * Advanced Mesh Routing
   * 
   * Enables experimental mesh routing algorithms
   * May impact battery life on mobile devices
   */
  ADVANCED_MESH_ROUTING: false,
  
  /**
   * Real-time Treasury Analytics
   * 
   * Enables live treasury data streaming
   * Requires WebSocket connections
   */
  REALTIME_TREASURY: true,
  
  /**
   * Mobile Mining Optimization
   * 
   * Enables advanced thermal management and CPU optimization
   * Currently in beta testing
   */
  MOBILE_MINING_OPTIMIZATION: true
} as const;

export type FeatureFlag = keyof typeof FEATURE_FLAGS;

/**
 * Check if a feature is enabled
 * @param flag Feature flag to check
 * @returns Whether the feature is enabled
 */
export function isFeatureEnabled(flag: FeatureFlag): boolean {
  return FEATURE_FLAGS[flag];
}