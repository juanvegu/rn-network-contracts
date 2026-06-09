import Foundation

/// Shared singleton between the React Native module and the bank's native
/// iOS app. The host populates the relevant fields **before** initializing
/// React Native; if ``provider`` is left `nil` the RN side falls back to
/// its JS `MockNetworkProvider`.
///
/// ### Initialization order
///
/// ```swift
/// RNNetworkRegistry.appConfig    = AppConfig(country: "CL", …)
/// RNNetworkRegistry.activeDomain = "BFF"
/// RNNetworkRegistry.provider     = AppNetworkProvider()       // optional
/// RNNetworkRegistry.onSessionExpired = { /* notify JS */ }
///
/// ReactNativeHostManager.shared.initialize()
/// ```
public final class RNNetworkRegistry {

    /// Host-provided network implementation. If `nil`, the RN side uses its
    /// JS-side mock provider as fallback (useful when running against a
    /// stubbed environment while the native HTTP stack is being built).
    public static var provider: NetworkProvider?

    /// Static description of the available domains. Immutable — to switch
    /// the active domain, mutate ``activeDomain`` instead of replacing this.
    public static var appConfig: AppConfig?

    /// Domain key currently used by the RN flow. Must match a `key` in
    /// `appConfig?.domains`. Mutable so the JS side (or the host) can switch
    /// domains without rebuilding ``appConfig``.
    public static var activeDomain: String?

    /// Optional callback the host invokes when it detects the user session
    /// has expired (e.g. token refresh failed after returning from background).
    ///
    /// The RN module subscribes to this and forwards the signal to JS as a
    /// `sessionExpired` event, so React code can navigate to a logout flow
    /// without waiting for the next request to fail.
    public static var onSessionExpired: (() -> Void)?

    /// Convenience derived value: the base URL for the currently active
    /// domain, or `nil` if either ``activeDomain`` or ``appConfig`` is unset.
    public static var activeBaseURL: String? {
        guard let key = activeDomain else { return nil }
        return appConfig?.domains.first { $0.key == key }?.baseURL
    }
}
