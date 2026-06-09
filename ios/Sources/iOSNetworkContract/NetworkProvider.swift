import Foundation

/// Core contract. The host implements this to perform network requests on
/// behalf of the React Native module.
///
/// ### Error handling
///
/// - For **domain-specific** failures (session expired, biometric required,
///   rate limited, …) throw ``NetworkError`` with a code the JS side can
///   branch on. The RN module forwards the full payload verbatim.
/// - For **system** failures (timeouts, SSL, connectivity) let the underlying
///   `URLError` propagate. The RN module's `NetworkErrorMapper` translates
///   it to standard codes.
/// - For **cancellation**, let `CancellationError` propagate. The RN mapper
///   translates it to `CANCELLED`.
/// - **Do NOT throw for non-2xx HTTP responses** — return the response as-is
///   in ``NetworkResponse/statusCode``; the RN module classifies it centrally
///   so the policy stays in one place.
///
/// ### Cancellation
///
/// The optional ``cancel(requestId:)`` method allows aborting an in-flight
/// request by ID. The default no-op covers hosts that don't support
/// cancellation. Hosts that do should look up the active task by
/// `requestId` and call `.cancel()` on it.
public protocol NetworkProvider {

    /// Perform an HTTP request.
    ///
    /// - Parameters:
    ///   - requestId: Opaque identifier the JS side uses to correlate this
    ///     call with a later ``cancel(requestId:)``. Hosts should associate
    ///     it with the underlying `URLSessionTask`.
    ///   - url: Absolute URL.
    ///   - method: HTTP method (`"GET"`, `"POST"`, …).
    ///   - headers: Request headers to send.
    ///   - body: Optional JSON-serializable body. Implementations decide
    ///     how to encode it; the recommended encoding is `application/json`.
    /// - Returns: Envelope with `statusCode`, `headers` and `data`. See
    ///   ``NetworkResponse`` for the contract around 204/empty bodies.
    /// - Throws: ``NetworkError`` for domain-specific failures the JS side
    ///   should branch on; system errors (`URLError`, `CancellationError`,
    ///   …) are translated by the RN module's mapper.
    func request(
        requestId: String,
        url: String,
        method: String,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> NetworkResponse

    /// Cancel a previously-issued request by its `requestId`. Default
    /// implementation is a no-op for hosts that don't support cancellation.
    func cancel(requestId: String)
}

public extension NetworkProvider {
    func cancel(requestId: String) { /* no-op default */ }
}
