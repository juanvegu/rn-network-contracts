package com.scotia.rnnetwork.contracts

/**
 * Core contract — must never change between versions.
 * New capabilities are added as optional interfaces
 * that extend this core.
 */
interface NetworkProvider {
    suspend fun request(
        url: String,
        method: String,
        headers: Map<String, String>,
        body: Map<String, Any?>?
    ): ByteArray
}

/**
 * Optional extension for countries that support cancellation.
 * The RN module detects this capability at runtime with graceful
 * degradation if the country has not implemented it.
 */
interface CancellableNetworkProvider : NetworkProvider {
    fun cancel(requestId: String)
}
