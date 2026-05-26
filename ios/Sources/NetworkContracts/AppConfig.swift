import Foundation

/// A single domain entry inside ``AppConfig/domains``. Each entry is a
/// symbolic name plus the base URL the RN flow will hit when that domain
/// is the active one.
public struct DomainConfig {
    /// Stable identifier (e.g. `"BFF"`, `"insurance"`). The active domain is
    /// referenced by this key on ``RNNetworkRegistry/activeDomain``.
    public let key: String

    /// Absolute URL with scheme. No trailing slash required.
    public let baseURL: String

    public init(key: String, baseURL: String) {
        self.key = key
        self.baseURL = baseURL
    }
}

/// Immutable description of the available domains for the RN flow. Assigned
/// by the host into ``RNNetworkRegistry/appConfig`` before initializing
/// React Native.
///
/// To switch the currently selected domain at runtime, mutate
/// ``RNNetworkRegistry/activeDomain`` instead of rebuilding this struct.
public struct AppConfig {
    /// ISO 3166-1 alpha-2 country code (e.g. `"CL"`).
    public let country: String

    /// Free-form environment label (`"prod"`, `"qa"`, …) surfaced to JS
    /// for diagnostics.
    public let environment: String

    /// Domains the RN flow may target. The currently active one is selected
    /// by key via ``RNNetworkRegistry/activeDomain``.
    public let domains: [DomainConfig]

    public init(country: String, environment: String, domains: [DomainConfig]) {
        self.country = country
        self.environment = environment
        self.domains = domains
    }
}
