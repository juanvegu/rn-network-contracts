package com.scotia.rnnetwork.contracts

/**
 * Core contract. The host implements this to perform network requests on
 * behalf of the React Native module.
 *
 * ### Error handling
 *
 * - For **domain-specific** failures (session expired, biometric required,
 *   rate limited, …) throw [NetworkError] with a code the JS side can
 *   branch on. The RN module forwards the full payload verbatim.
 * - For **system** failures (timeouts, SSL, connectivity) let the underlying
 *   exception propagate (`SocketTimeoutException`, `SSLException`,
 *   `UnknownHostException`, `IOException`). The RN module's
 *   `NetworkErrorMapper` translates them to standard codes.
 * - For **cancellation**, let `CancellationException` propagate. The RN
 *   mapper translates it to `CANCELLED`.
 * - **Do NOT throw for non-2xx HTTP responses** — return the response as-is
 *   in [NetworkResponse.statusCode]; the RN module classifies it centrally
 *   so the policy stays in one place.
 *
 * ### Cancellation
 *
 * The optional [cancel] method allows aborting an in-flight request by ID.
 * The default no-op covers hosts that don't support cancellation. Hosts that
 * do should look up the active call by `requestId` (e.g. via `OkHttp` request
 * tags) and call `.cancel()` on it.
 */
interface NetworkProvider {

    /**
     * Perform an HTTP request.
     *
     * @param requestId Opaque identifier the JS side uses to correlate this
     *                  call with a later [cancel] call. Hosts should attach
     *                  it to their underlying request (e.g. OkHttp's
     *                  `Request.Builder.tag()`).
     * @param url Absolute URL.
     * @param method HTTP method (`"GET"`, `"POST"`, …).
     * @param headers Request headers to send.
     * @param body Optional JSON-serializable body. Implementations decide
     *             how to encode it; the recommended encoding is `application/json`.
     * @return Envelope with `statusCode`, `headers` and `data`. See
     *         [NetworkResponse] for the contract around 204/empty bodies.
     * @throws NetworkError for domain-specific failures the JS side should
     *         branch on.
     */
    suspend fun request(
        requestId: String,
        url: String,
        method: String,
        headers: Map<String, String>,
        body: Map<String, Any?>?
    ): NetworkResponse

    /**
     * Cancel a previously-issued request by its [requestId]. Default
     * implementation is a no-op for hosts that don't support cancellation.
     */
    fun cancel(requestId: String) { /* no-op default */ }
}
