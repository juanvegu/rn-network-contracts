package com.scotia.rnnetwork.contracts

/**
 * Shared singleton between the RN App AAB
 * and the bank's native app.
 * The bank must assign the provider BEFORE initializing React Native.
 */
object RNNetworkRegistry {
    var provider: NetworkProvider? = null
}
