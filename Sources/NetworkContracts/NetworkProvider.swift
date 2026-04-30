import Foundation

/// Core contract — must never change between versions.
/// New capabilities are added as optional protocols that extend this core.
public protocol NetworkProvider {
    func request(
        url: String,
        method: String,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> Data
}

/// Optional extension for countries that support cancellation.
/// The RN module detects this capability at runtime with graceful
/// degradation if the country has not implemented it.
public protocol CancellableNetworkProvider: NetworkProvider {
    func cancel(requestId: String)
}
