package com.scotia.rnnetwork.contracts

/**
 * Envelope returned by [NetworkProvider.request] on success.
 *
 * The RN module enforces "2xx = success, anything else = error" centrally
 * based on [statusCode], so the host never has to remember to throw for
 * non-2xx responses — just return the response as-is.
 *
 * @property data `null` for 204/No-Content or empty bodies.
 */
data class NetworkResponse(
    val statusCode: Int,
    val headers: Map<String, String> = emptyMap(),
    val data: ByteArray?,
)
