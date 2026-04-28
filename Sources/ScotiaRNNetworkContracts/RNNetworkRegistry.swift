import Foundation

/// Shared singleton between the RN App xcframework
/// and the bank's native app.
/// The bank must assign the provider BEFORE initializing React Native.
public final class RNNetworkRegistry {
    public static var provider: NetworkProvider?
}
