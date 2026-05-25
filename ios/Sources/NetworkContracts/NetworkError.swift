import Foundation

/// Typed error a `NetworkProvider` may throw to communicate domain-specific
/// failures (session expired, biometric required, rate limited, etc.) without
/// going through the generic `NetworkErrorMapper`.
///
/// Standard codes are documented in the README; hosts can introduce their
/// own with a clear prefix (e.g. `SCOTIA_KYC_PENDING`).
public struct NetworkError: Error {
    public let code: String
    public let retryable: Bool
    public let httpStatus: Int?
    public let message: String?
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
