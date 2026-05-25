import Foundation

/// Envelope returned by `NetworkProvider.request(...)` on success.
///
/// The RN module enforces "2xx = success, anything else = error" centrally
/// based on `statusCode`, so the host never has to remember to throw for
/// non-2xx responses — just return the response as-is.
public struct NetworkResponse {
    public let statusCode: Int
    public let headers: [String: String]
    /// `nil` for 204/No-Content or empty bodies.
    public let data: Data?

    public init(statusCode: Int, headers: [String: String] = [:], data: Data? = nil) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}
