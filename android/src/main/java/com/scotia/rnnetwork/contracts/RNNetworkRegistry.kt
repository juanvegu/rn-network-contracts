package com.scotia.rnnetwork.contracts

/**
 * Shared singleton between the RN App AAB and the bank's native app.
 * The bank assigns `provider` BEFORE initializing React Native. If `provider`
 * is left null, the RN side will fall back to its JS MockNetworkProvider.
 */
object RNNetworkRegistry {
    var provider: NetworkProvider? = null
    var appConfig: AppConfig? = null

    /** Domain key used at RN flow startup. Mutable to switch domains at runtime
     *  without rebuilding `appConfig`. Must match a `key` in `appConfig?.domains`. */
    var activeDomain: String? = null

    /** Invoked by the host (or by an internal mapper) when the user session
     *  expires while RN is idle. Forwarded to JS as a `sessionExpired` event. */
    var onSessionExpired: (() -> Unit)? = null

    val activeBaseURL: String?
        get() = activeDomain?.let { key ->
            appConfig?.domains?.firstOrNull { it.key == key }?.baseURL
        }
}
