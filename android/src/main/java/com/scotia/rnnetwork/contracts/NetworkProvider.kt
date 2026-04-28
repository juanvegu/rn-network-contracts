package com.scotia.rnnetwork.contracts

/**
 * Contrato núcleo — nunca debe cambiar entre versiones.
 * Nuevas capacidades se agregan como interfaces opcionales
 * que extienden este núcleo.
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
 * Extensión opcional para países que soporten cancelación.
 * El módulo RN detecta esta capacidad en runtime con degradación
 * elegante si el país no la implementó.
 */
interface CancellableNetworkProvider : NetworkProvider {
    fun cancel(requestId: String)
}
