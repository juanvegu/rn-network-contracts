import Foundation

/// Envelope returned by ``NetworkProvider/request(requestId:url:method:headers:body:)``
/// on success. Carries the raw HTTP envelope so the RN module can:
///
/// 1. Enforce the "2xx == success, anything else == error" rule centrally
///    based on `statusCode` — the host never has to remember to throw for
///    non-2xx responses.
/// 2. Surface response metadata (`headers`, `statusCode`) to JS so RN code
///    can read `Retry-After`, `X-Trace-Id`, etc.
/// 3. Express 204/empty bodies cleanly via `data == nil`.
public struct NetworkResponse {
    /// HTTP status code as returned by the underlying client.
    public let statusCode: Int

    /// Response headers. Keys are case-insensitive per HTTP but forwarded
    /// as-is.
    public let headers: [String: String]

    /// Response body bytes. `nil` for `204 No Content` or empty bodies —
    /// the RN module turns this into an empty object on the JS side.
    public let data: Data?

    public init(statusCode: Int, headers: [String: String] = [:], data: Data? = nil) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}
