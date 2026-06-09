import Foundation

/// Typed error a ``NetworkProvider`` throws to communicate a domain-specific
/// failure without going through the generic system-error mapper.
///
/// The RN module preserves all fields verbatim when surfacing the error to JS,
/// so React code can branch on `code` and inspect `httpStatus`/`message`/`info`.
///
/// Standard codes are documented in the README (`SESSION_EXPIRED`,
/// `RATE_LIMITED`, …). Hosts may introduce additional codes with a clear
/// prefix (e.g. `SCOTIA_KYC_PENDING`).
public struct NetworkError: Error {

    /// Stable, machine-readable identifier the JS side branches on.
    public let code: String

    /// Hint to the JS side: is it worth retrying? (`500` → usually `true`;
    /// `401` session-expired → `false`).
    public let retryable: Bool

    /// Original HTTP status code, if the error originated from an HTTP response.
    public let httpStatus: Int?

    /// Optional human-readable detail. Forwarded to JS for logging/UI.
    public let message: String?

    /// Optional structured payload (e.g. `["retryAfter": 30]`). Must be
    /// serializable across the JS bridge.
    public let info: [String: Any]?

    public init(
        code: String,
        retryable: Bool = false,
        httpStatus: Int? = nil,
        message: String? = nil,
        info: [String: Any]? = nil
    ) {
        self.code = code
        self.retryable = retryable
        self.httpStatus = httpStatus
        self.message = message
        self.info = info
    }
}
