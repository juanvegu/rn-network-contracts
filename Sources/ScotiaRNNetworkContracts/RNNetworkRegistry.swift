import Foundation

/// Singleton compartido entre el xcframework de la App RN
/// y la app nativa del banco.
/// El banco debe asignar provider ANTES de inicializar React Native.
public final class RNNetworkRegistry {
    public static var provider: NetworkProvider?
}
