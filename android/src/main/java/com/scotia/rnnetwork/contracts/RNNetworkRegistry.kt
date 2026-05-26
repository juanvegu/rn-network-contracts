package com.scotia.rnnetwork.contracts

/**
 * Shared singleton between the React Native module and the bank's native
 * Android app. The host populates the relevant fields **before** initializing
 * React Native; if [provider] is left `null` the RN side falls back to its
 * JS `MockNetworkProvider`.
 *
 * ### Initialization order
 *
 * ```kotlin
 * RNNetworkRegistry.appConfig    = AppConfig(country = "CL", …)
 * RNNetworkRegistry.activeDomain = "BFF"
 * RNNetworkRegistry.provider     = AppNetworkProvider(...)  // optional
 * RNNetworkRegistry.onSessionExpired = { /* notify JS */ }
 *
 * ReactNativeHostManager.initialize(this)
 * ```
 */
object RNNetworkRegistry {

    /**
     * Host-provided network implementation. If `null`, the RN side uses its
     * JS-side mock provider as fallback (useful when running against a
     * stubbed environment while the native HTTP stack is being built).
     */
    var provider: NetworkProvider? = null

    /**
     * Static description of the available domains. Immutable — to switch
     * the active domain, mutate [activeDomain] instead of replacing this.
     */
    var appConfig: AppConfig? = null

    /**
     * Domain key currently used by the RN flow. Must match a `key` in
     * `appConfig?.domains`. Mutable so the JS side (or the host) can switch
     * domains without rebuilding [appConfig].
     */
    var activeDomain: String? = null

    /**
     * Optional callback the host invokes when it detects the user session
     * has expired (e.g. token refresh failed after returning from background).
     *
     * The RN module subscribes to this and forwards the signal to JS as a
     * `sessionExpired` event, so React code can navigate to a logout flow
     * without waiting for the next request to fail.
     */
    var onSessionExpired: (() -> Unit)? = null

    /**
     * Convenience derived value: the base URL for the currently active
     * domain, or `null` if either [activeDomain] or [appConfig] is unset.
     */
    val activeBaseURL: String?
        get() = activeDomain?.let { key ->
            appConfig?.domains?.firstOrNull { it.key == key }?.baseURL
        }
}
