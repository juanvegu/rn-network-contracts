package com.scotia.rnnetwork.contracts

/**
 * Core contract. Hosts implement this to perform network requests on behalf
 * of the React Native module. `cancel` is optional — the default no-op
 * covers hosts that don't support cancellation.
 *
 * Errors:
 * - For domain-specific failures (session expired, biometric required,
 *   rate limited, etc.) throw [NetworkError] with a code the JS side can
 *   branch on.
 * - For system failures (timeouts, SSL, connectivity) you may either
 *   throw the underlying [java.io.IOException] / [kotlinx.coroutines.CancellationException]
 *   (the RN module's mapper translates them to standard codes) or wrap them
 *   in [NetworkError].
 * - Do NOT throw for non-2xx HTTP responses — return the response and let
 *   the RN module classify by [NetworkResponse.statusCode].
 */
interface NetworkProvider {
    suspend fun request(
        requestId: String,
        url: String,
        method: String,
        headers: Map<String, String>,
        body: Map<String, Any?>?
    ): NetworkResponse

    fun cancel(requestId: String) { /* no-op default */ }
}
