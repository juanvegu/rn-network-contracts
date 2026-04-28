# rn-network-contracts

Contrato formal entre las apps nativas del banco y `@scotia/rn-network`.

Define las interfaces `NetworkProvider` y `RNNetworkRegistry` para iOS (SPM) y Android (Gradle). No tiene dependencias externas, no importa React Native ni Expo.

## Estrategia de versionado

El contrato núcleo (`NetworkProvider.request`) nunca cambia entre versiones para no romper países que aún no han actualizado. Las nuevas capacidades se agregan como protocolos/interfaces opcionales (ej. `CancellableNetworkProvider`) que el módulo RN detecta en runtime con degradación elegante.

---

## iOS

### Escenario 1 — País con LibraryNativeNetwork

```swift
// 1. Agregar paquete SPM en Xcode:
//    https://github.com/scotia/rn-network-contracts
//    Producto: ScotiaRNNetworkContracts

// 2. LibraryNativeNetwork implementa el contrato:
import ScotiaRNNetworkContracts

extension LibraryNativeNetwork: NetworkProvider {
    public func request(
        url: String,
        headers: [String: String]
    ) async throws -> Data {
        return try await self.performRequest(url: url, headers: headers)
    }
}

// 3. En la inicialización de LibraryNativeNetwork,
//    ANTES de montar React Native:
RNNetworkRegistry.provider = LibraryNativeNetwork.shared
```

### Escenario 2 — País sin LibraryNativeNetwork

```swift
// 1. Agregar paquete SPM en Xcode:
//    https://github.com/scotia/rn-network-contracts
//    Producto: ScotiaRNNetworkContracts

// 2. En AppDelegate, ANTES de montar React Native:
import ScotiaRNNetworkContracts

class AppNetworkProvider: NetworkProvider {
    public func request(
        url: String,
        headers: [String: String]
    ) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

RNNetworkRegistry.provider = AppNetworkProvider()
ReactNativeHostManager.shared.initialize()
```

---

## Android

### Escenario 1 — País con LibraryNativeNetwork

```kotlin
// 1. Agregar en build.gradle:
implementation 'com.scotia:rn-network-contracts:1.0.0'

// 2. LibraryNativeNetwork implementa el contrato:
import com.scotia.rnnetwork.contracts.NetworkProvider
import com.scotia.rnnetwork.contracts.RNNetworkRegistry

class LibraryNativeNetwork : NetworkProvider {
    override suspend fun request(
        url: String,
        headers: Map<String, String>
    ): ByteArray = performRequest(url, headers)
}

// 3. En inicialización, ANTES de montar React Native:
RNNetworkRegistry.provider = LibraryNativeNetwork.getInstance()
```

### Escenario 2 — País sin LibraryNativeNetwork

```kotlin
// 1. Agregar en build.gradle:
implementation 'com.scotia:rn-network-contracts:1.0.0'

// 2. En Application.onCreate(), ANTES de montar React Native:
import com.scotia.rnnetwork.contracts.NetworkProvider
import com.scotia.rnnetwork.contracts.RNNetworkRegistry

class AppNetworkProvider : NetworkProvider {
    override suspend fun request(
        url: String,
        headers: Map<String, String>
    ): ByteArray {
        // implementación directa con OkHttp o similar
    }
}

RNNetworkRegistry.provider = AppNetworkProvider()
ReactNativeHostManager.initialize(application)
```

---

## Escenario 3 — App full RN (países con desarrollo full RN)

```typescript
// No requiere ScotiaRNNetworkContracts.
// La app RN inyecta su propio provider desde JS
// usando setProvider() antes del primer request.
import { setProvider } from '@scotia/rn-network'

if (!RNNetworkBridge.isAvailable()) {
    setProvider({
        async request(url, headers) {
            const response = await fetch(url, { headers })
            return response.json()
        }
    })
}
```
