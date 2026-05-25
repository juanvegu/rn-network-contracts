package com.scotia.rnnetwork.contracts

data class DomainConfig(val key: String, val baseURL: String)

data class AppConfig(
    val country: String,
    val environment: String,
    val domains: List<DomainConfig>,
)
