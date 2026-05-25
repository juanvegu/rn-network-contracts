package com.scotia.rnnetwork.contracts

/**
 * Typed error a [NetworkProvider] may throw to communicate domain-specific
 * failures (session expired, biometric required, rate limited, etc.) without
 * going through the generic `NetworkErrorMapper`.
 *
 * Standard codes are documented in the README; hosts can introduce their
 * own with a clear prefix (e.g. `SCOTIA_KYC_PENDING`).
 */
class NetworkError(
    val code: String,
    val retryable: Boolean = false,
    val httpStatus: Int? = null,
    message: String? = null,
    val info: Map<String, Any?>? = null,
) : Exception(message)
