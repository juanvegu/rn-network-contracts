package com.scotia.rnnetwork.contracts

/**
 * Envelope returned by [NetworkProvider.request] on success. Carries the
 * raw HTTP envelope so the RN module can:
 *
 * 1. Enforce the "2xx == success, anything else == error" rule centrally
 *    based on [statusCode] — the host never has to remember to throw
 *    for non-2xx.
 * 2. Surface response metadata ([headers], [statusCode]) to JS so RN code
 *    can read `Retry-After`, `X-Trace-Id`, etc.
 * 3. Express 204/empty bodies cleanly via `data == null`.
 *
 * @property statusCode HTTP status code as returned by the underlying client.
 * @property headers Response headers. Keys are case-insensitive per HTTP but
 *                   forwarded as-is.
 * @property data Response body bytes. `null` for `204 No Content` or empty
 *                bodies — the RN module turns this into an empty object on
 *                the JS side.
 */
data class NetworkResponse(
    val statusCode: Int,
    val headers: Map<String, String> = emptyMap(),
    val data: ByteArray?,
)
