import Foundation

/// Contrato núcleo — nunca debe cambiar entre versiones.
/// Nuevas capacidades se agregan como protocolos opcionales
/// que extienden este núcleo.
public protocol NetworkProvider {
    func request(url: String, headers: [String: String]) async throws -> Data
}

/// Extensión opcional para países que soporten cancelación.
/// El módulo RN detecta esta capacidad en runtime con degradación
/// elegante si el país no la implementó.
public protocol CancellableNetworkProvider: NetworkProvider {
    func cancel(requestId: String)
}
