import Foundation

public struct DomainConfig {
    public let key: String
    public let baseURL: String

    public init(key: String, baseURL: String) {
        self.key = key
        self.baseURL = baseURL
    }
}

public struct AppConfig {
    public let country: String
    public let environment: String
    public let domains: [DomainConfig]

    public init(country: String, environment: String, domains: [DomainConfig]) {
        self.country = country
        self.environment = environment
        self.domains = domains
    }
}
