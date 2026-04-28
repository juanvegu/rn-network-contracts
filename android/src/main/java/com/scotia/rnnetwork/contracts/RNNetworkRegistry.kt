package com.scotia.rnnetwork.contracts

/**
 * Singleton compartido entre el AAB de la App RN
 * y la app nativa del banco.
 * El banco debe asignar provider ANTES de inicializar React Native.
 */
object RNNetworkRegistry {
    var provider: NetworkProvider? = null
}
