package com.scotia.rnnetwork.contracts

/**
 * A single domain entry inside [AppConfig.domains]. Each entry is a
 * symbolic name plus the base URL the RN flow will hit when that domain
 * is the active one.
 *
 * @property key Stable identifier (e.g. `"BFF"`, `"insurance"`). The active
 *               domain is referenced by this key on [RNNetworkRegistry.activeDomain].
 * @property baseURL Absolute URL with scheme. No trailing slash required.
 */
data class DomainConfig(val key: String, val baseURL: String)

/**
 * Immutable description of the available domains for the RN flow. Assigned
 * by the host into [RNNetworkRegistry.appConfig] before initializing
 * React Native.
 *
 * To switch the currently selected domain at runtime, mutate
 * [RNNetworkRegistry.activeDomain] instead of rebuilding this object.
 *
 * @property country ISO 3166-1 alpha-2 country code (e.g. `"CL"`).
 * @property environment Free-form environment label (`"prod"`, `"qa"`, …)
 *                       surfaced to JS for diagnostics.
 * @property domains Domains the RN flow may target. The currently active one
 *                   is selected by key via [RNNetworkRegistry.activeDomain].
 */
data class AppConfig(
    val country: String,
    val environment: String,
    val domains: List<DomainConfig>,
)
