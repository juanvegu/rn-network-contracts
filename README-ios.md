# iOSNetworkContract (rn-network-contracts-ios)

Contrato Swift que la app nativa iOS de Scotia implementa para que el módulo Expo `@scotia/rn-network` enrute sus requests HTTP a través del stack del banco (URLSession con pinning, sesión, telemetría).

Repo binario, sin dependencias externas, sin importar React Native ni Expo.

> **Repo hermano (Android):** `rn-network-contracts-android`. Ambos van al mismo `MAJOR.MINOR`.

---

## Distribución: source (SPM) o binario (xcframework)

El contrato es **dual-capable**:

- **Source vía SPM** — el `Package.swift` compila los `.swift` directamente. Sirve para un consumidor SPM aislado.
- **Binario vía xcframework** — un `.xcframework` precompilado, consumible por SPM (`.binaryTarget`) **y** CocoaPods (`vendored_frameworks`).

**Usamos el binario (xcframework), no source.** No es porque SPM falle — es por una **limitación del ecosistema Expo/React Native**:

- Expo Modules está atado a CocoaPods (ExpoModulesCore, autolinking, brownfield)
- No hay soporte SPM nativo en Expo todavía (RN 0.84+ roadmap; SDK 56 experimental)
- El plugin `cocoapods-spm` está vetado por seguridad del banco

Para compartir **una sola instancia** de `RNNetworkRegistry` entre la app nativa (SPM) y el módulo Expo (CocoaPods), ambos tienen que apuntar al **mismo binario**. Source-en-ambos-lados daría dos compilaciones → dos singletons → contrato roto.

**Cuándo volver a source:** cuando Expo/RN soporten SPM first-class. Hasta entonces, binario.

---

## Tipos públicos

| Tipo | Descripción |
|---|---|
| `NetworkProvider` | Protocolo que el host implementa. `request(requestId:url:method:headers:body:) async throws -> NetworkResponse` + `cancel(requestId:)` opcional |
| `NetworkResponse` | Envelope de éxito: `statusCode`, `headers`, `data?` |
| `NetworkError` | Error tipado del host: `code`, `retryable`, `httpStatus?`, `message?`, `info?` |
| `AppConfig` / `DomainConfig` | Descripción inmutable de dominios disponibles |
| `RNNetworkRegistry` | Singleton: `provider`, `appConfig`, `activeDomain`, `onSessionExpired` |

### Cuándo lanzar vs retornar

| Situación | Acción del host |
|---|---|
| HTTP 2xx | `NetworkResponse(statusCode: 200, headers:, data: bytes)` |
| HTTP 204 | `NetworkResponse(statusCode: 204, data: nil)` |
| HTTP non-2xx | **NO clasificar** — retornar la response; el módulo RN clasifica |
| Falla de dominio (sesión, biometría) | `throw NetworkError(code: "SESSION_EXPIRED", …)` |
| Timeout / SSL / connectivity / cancel | Dejar propagar `URLError` / `CancellationError` |

---

## Consumir el xcframework

### App nativa (SPM)

```swift
// Producción — Package.swift, snippet del DISTRIBUTION.md publicado
.binaryTarget(
    name: "iOSNetworkContract",
    url: "https://artifactory.scotiabank.cl/ios/iOSNetworkContract/1.1.0/iOSNetworkContract.xcframework.zip",
    checksum: "<sha256>"
)

// Dev local — path al build local
.binaryTarget(name: "iOSNetworkContract", path: "../rn-network-contracts/build/iOSNetworkContract.xcframework")
```

### Módulo Expo (CocoaPods, vendored)

El módulo `@scotia/rn-network` bundlea el xcframework. Ver su podspec (`vendored_frameworks` + `user_target_xcconfig`).

---

## Implementar el provider

```swift
import iOSNetworkContract
import Foundation

final class AppNetworkProvider: NetworkProvider {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func request(
        requestId: String, url: String, method: String,
        headers: [String: String], body: [String: Any]?
    ) async throws -> NetworkResponse {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let body = body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError(code: "UNKNOWN", retryable: false)
        }
        if http.statusCode == 401, http.value(forHTTPHeaderField: "X-Session-Expired") == "true" {
            throw NetworkError(code: "SESSION_EXPIRED", retryable: false, httpStatus: 401)
        }
        let headers = (http.allHeaderFields as? [String: String]) ?? [:]
        return NetworkResponse(statusCode: http.statusCode, headers: headers,
                               data: http.statusCode == 204 ? nil : data)
    }

    func cancel(requestId: String) { /* buscar el URLSessionTask y .cancel() */ }
}
```

## Registrar antes de iniciar RN

```swift
import iOSNetworkContract

RNNetworkRegistry.appConfig = AppConfig(
    country: "CL", environment: "prod",
    domains: [DomainConfig(key: "BFF", baseURL: "https://api.bank.cl")]
)
RNNetworkRegistry.activeDomain = "BFF"
RNNetworkRegistry.provider = AppNetworkProvider()        // si nil → RN cae al mock JS
RNNetworkRegistry.onSessionExpired = { /* notificar al JS */ }

ReactNativeHostManager.shared.initialize()               // SIEMPRE al final
```

---

## Desarrollo

```bash
swift build                          # compila la librería (source)
swift test                           # tests
./scripts/build-xcframework.sh       # genera el xcframework
./scripts/build-and-sync.sh          # build + sync al módulo Expo (dev local)
```

## Release (Fastlane + Jenkins)

```bash
fastlane test                        # swift build + test
fastlane build_xcframework           # genera el binario sin publicar
fastlane release bump:minor          # bump tag + build + upload + DISTRIBUTION.md
```

El pipeline (manual desde Jenkins) versiona por **git tag**, genera el xcframework con `build-xcframework.sh`, lo sube a Artifactory, y escribe `DISTRIBUTION.md` con la URL + checksum.

> NO se usa `fastlane-plugin-create_xcframework` — falla con Swift Packages puros (bitcode deprecado + framework sin `Modules/swiftinterface`). El script maneja los gotchas de SwiftPM.

## Estructura (repo iOS-only en el banco)

```
rn-network-contracts-ios/
├── Package.swift                     ← source, para build script + tests
├── scripts/
│   ├── build-xcframework.sh
│   └── build-and-sync.sh
├── Sources/iOSNetworkContract/       ← sin prefijo ios/ (repo iOS-only)
├── Tests/iOSNetworkContractTests/
├── fastlane/Fastfile
├── Jenkinsfile
└── Gemfile
```

> En el prototipo combinado (iOS+Android) los Sources viven en `ios/Sources/...`. Al separar en el repo iOS-only del banco, suben a la raíz (`Sources/...`) y se quita el prefijo `ios/` de los `path:` del `Package.swift`.

## Versionado

- **Versión = git tag.** No hay podspec que bumpear.
- La app nativa y el módulo Expo deben usar la **misma versión** del xcframework (sino `Symbol not found` en runtime).
- iOS ↔ Android van al mismo `MAJOR.MINOR`.
