package com.scotia.rnnetwork.contracts

/**
 * Typed error a [NetworkProvider] throws to communicate a domain-specific
 * failure without going through the generic system-error mapper.
 *
 * The RN module preserves all fields verbatim when surfacing the error to JS,
 * so React code can branch on [code] and inspect [httpStatus]/[message]/[info].
 *
 * Standard codes are documented in the README (`SESSION_EXPIRED`,
 * `RATE_LIMITED`, …). Hosts may introduce additional codes with a clear
 * prefix (e.g. `SCOTIA_KYC_PENDING`).
 *
 * @property code Stable, machine-readable identifier the JS side branches on.
 * @property retryable Hint to the JS side: is it worth retrying? (`500` →
 *                     usually `true`; `401` session-expired → `false`).
 * @property httpStatus Original HTTP status code, if the error originated
 *                      from an HTTP response.
 * @property info Optional structured payload (e.g. `mapOf("retryAfter" to 30)`).
 *                Must be serializable across the JS bridge.
 */
class NetworkError(
    val code: String,
    val retryable: Boolean = false,
    val httpStatus: Int? = null,
    message: String? = null,
    val info: Map<String, Any?>? = null,
) : Exception(message)
