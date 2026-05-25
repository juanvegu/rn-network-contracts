import Foundation

/// Core contract. Hosts implement this to perform network requests on behalf
/// of the React Native module. `cancel` is optional — the default no-op
/// covers hosts that don't support cancellation.
///
/// Errors:
/// - For domain-specific failures (session expired, biometric required,
///   rate limited, etc.) throw `NetworkError` with a code the JS side can
///   branch on.
/// - For system failures (timeouts, SSL, connectivity) you may either
///   throw the underlying `URLError`/`CancellationError` (the RN module's
///   mapper translates them to standard codes) or wrap them in `NetworkError`.
/// - Do NOT throw for non-2xx HTTP responses — return the response and let
///   the RN module classify by `statusCode`.
public protocol NetworkProvider {
    func request(
        url: String,
        method: String,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> NetworkResponse

    func cancel(requestId: String)
}

public extension NetworkProvider {
    func cancel(requestId: String) { /* no-op default */ }
}
