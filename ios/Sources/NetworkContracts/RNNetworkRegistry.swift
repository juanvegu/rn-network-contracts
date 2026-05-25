import Foundation

/// Shared singleton between the RN App xcframework and the bank's native app.
/// The bank assigns `provider` BEFORE initializing React Native. If `provider`
/// is left nil, the RN side will fall back to its JS MockNetworkProvider.
public final class RNNetworkRegistry {
    public static var provider: NetworkProvider?
    public static var appConfig: AppConfig?

    /// Domain key used at RN flow startup. Mutable to switch domains at runtime
    /// without rebuilding `appConfig`. Must match a `key` in `appConfig?.domains`.
    public static var activeDomain: String?

    /// Invoked by the host (or by an internal mapper) when the user session
    /// expires while RN is idle. Forwarded to JS as a `sessionExpired` event.
    public static var onSessionExpired: (() -> Void)?

    public static var activeBaseURL: String? {
        guard let key = activeDomain else { return nil }
        return appConfig?.domains.first { $0.key == key }?.baseURL
    }
}
