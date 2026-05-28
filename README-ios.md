# rn-network-contracts-ios

Contrato Swift que la app nativa iOS de Scotia implementa para que el módulo Expo `@scotia/rn-network` pueda enrutar sus requests HTTP a través del stack del banco (URLSession con pinning, sesión, telemetría).

Repo binario, sin dependencias externas, sin importar React Native ni Expo. Se distribuye vía **Swift Package Manager** y **CocoaPods** (mismo árbol de sources).

> **Repo hermano (Android):** [`rn-network-contracts-android`](https://bitbucket.scotiabank.com/projects/<PROJECT>/repos/rn-network-contracts-android). Ambos van siempre al mismo `MAJOR.MINOR` — cualquier cambio al contrato requiere PRs sincronizados.

---

## Arquitectura en un diagrama

```
┌──────────────────────────┐         ┌──────────────────────────────┐
│  App nativa iOS          │         │ @scotia/rn-network (Expo)    │
│                          │         │                              │
│  AppNetworkProvider  ────┼─── via ─┼─►  RNNetworkBridge (JS) ─►   │
│  (URLSession,            │ Registry│      request(url, …)         │
│   pinning, session)      │         │                              │
│                          │         │  RnNetworkModule (Swift)     │
│  RNNetworkRegistry       │         │   ├─ enforces 2xx            │
│   ├─ provider            │         │   ├─ surfaces statusCode +   │
│   ├─ appConfig           │         │   │  headers to JS           │
│   ├─ activeDomain        │         │   └─ emits sessionExpired    │
│   └─ onSessionExpired    │         │                              │
└──────────────────────────┘         └──────────────────────────────┘

           ────────────────── contrato: rn-network-contracts-ios ──────────────────
                                (Swift Package + CocoaPod)
```

La app nativa **asigna `RNNetworkRegistry.provider`** antes de inicializar React Native. Si no lo asigna, la RN cae a su `MockNetworkProvider` JS (útil cuando el host arranca en stubbed mode).

---

## Tipos públicos

| Tipo | Descripción |
|---|---|
| `NetworkProvider` | Protocolo que el host implementa para hacer requests. Un método (`request`) más `cancel` opcional. |
| `NetworkResponse` | Envelope de éxito: `statusCode`, `headers`, `data`. |
| `NetworkError` | Error tipado que el host lanza para fallas de dominio (`SESSION_EXPIRED`, `RATE_LIMITED`, etc.). |
| `AppConfig` | Descripción inmutable de los dominios disponibles para el flujo RN (`country`, `environment`, `domains`). |
| `DomainConfig` | Entrada `{ key, baseURL }` dentro de `AppConfig.domains`. |
| `RNNetworkRegistry` | Singleton compartido. El host popula `provider`, `appConfig`, `activeDomain`, `onSessionExpired`. |

### Cuándo lanzar vs cuándo retornar

| Situación | Acción del host |
|---|---|
| HTTP 2xx | Retornar `NetworkResponse(statusCode: 200, headers: …, data: bytes)` |
| HTTP 204 | Retornar `NetworkResponse(statusCode: 204, headers: …, data: nil)` |
| HTTP non-2xx | **NO clasificar** — retornar la response tal cual; el módulo RN se encarga |
| Falla de dominio (sesión expirada, biometría, etc.) | `throw NetworkError(code: "SESSION_EXPIRED", …)` |
| Timeout / SSL / conectividad | Dejar propagar el `URLError` — el mapper del módulo RN lo traduce |
| Task cancelada | Dejar propagar `CancellationError` |

---

## Códigos de error estándar

El módulo RN garantiza que estos códigos lleguen al JS. El host puede definir códigos propios (prefijo recomendado: `SCOTIA_KYC_PENDING`, `SCOTIA_BIOMETRIC_REQUIRED`, …).

| Código | Origen | `retryable` | Notas |
|---|---|---|---|
| `SSL_PINNING_FAILED` | mapper | false | Cert mismatch / chain falla |
| `TIMEOUT` | mapper / cliente JS | true | Servidor no respondió |
| `NO_CONNECTIVITY` | mapper | true | Sin red, DNS falla |
| `HTTP_CLIENT_ERROR` | módulo (4xx) | false | Asignado automático |
| `HTTP_SERVER_ERROR` | módulo (5xx) | true | Asignado automático |
| `INVALID_RESPONSE_BODY` | módulo | false | 2xx con body no JSON |
| `CANCELLED` | mapper | false | Task cancelado |
| `SESSION_EXPIRED` | host | false | Usuario vuelve, sesión ya no válida |
| `SESSION_UNAUTHORIZED` | host | false | 401 que no es expiración |
| `PROVIDER_NOT_SET` | módulo | false | Sin provider y sin fallback JS |
| `UNKNOWN` | mapper | false | Error no mapeado |

---

## Instalación

### Swift Package Manager

```swift
// Package.swift consumer
.package(url: "https://bitbucket.scotiabank.com/scm/<project>/rn-network-contracts-ios.git", from: "1.0.0")
```

O desde Xcode → File → Add Package Dependencies → URL del repo.

### CocoaPods

```ruby
# Podfile consumer
pod 'NetworkContracts', '~> 1.0.0', :source => 'https://bitbucket.scotiabank.com/scm/<project>/scotia-specs.git'
```

> **Por qué ambos:** Expo Modules consume vía CocoaPods. La app nativa de Scotia migrando a SPM lo consume vía SPM. Ambos viven en el mismo repo y resuelven a los mismos `Sources/`.

---

## Implementando el contrato

```swift
import NetworkContracts
import Foundation

final class AppNetworkProvider: NetworkProvider {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func request(
        requestId: String,
        url: String,
        method: String,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> NetworkResponse {
        guard let parsed = URL(string: url) else {
            throw NetworkError(code: "UNKNOWN", retryable: false)
        }

        var req = URLRequest(url: parsed)
        req.httpMethod = method
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            if req.value(forHTTPHeaderField: "Content-Type") == nil {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError(code: "UNKNOWN", retryable: false)
        }

        // Señal de dominio: 401 con header específico → error tipado, no 4xx genérico.
        if http.statusCode == 401,
           http.value(forHTTPHeaderField: "X-Session-Expired") == "true" {
            throw NetworkError(code: "SESSION_EXPIRED", retryable: false, httpStatus: 401)
        }

        let headers = (http.allHeaderFields as? [String: String]) ?? [:]
        return NetworkResponse(
            statusCode: http.statusCode,
            headers: headers,
            data: http.statusCode == 204 ? nil : data
        )
    }

    func cancel(requestId: String) {
        // Opcional. Buscar el URLSessionTask asociado al requestId y `.cancel()` sobre él.
    }
}
```

---

## Registrando antes de iniciar RN

```swift
// AppDelegate.application(_:didFinishLaunchingWithOptions:)
import NetworkContracts

RNNetworkRegistry.provider = AppNetworkProvider()

RNNetworkRegistry.appConfig = AppConfig(
    country: "CL",
    environment: "prod",
    domains: [DomainConfig(key: "BFF", baseURL: "https://api.bank.cl")]
)
RNNetworkRegistry.activeDomain = "BFF"

RNNetworkRegistry.onSessionExpired = { [weak self] in
    // Lo que el host quiera hacer cuando detecta sesión vencida.
    // El módulo RN forwardea esto al JS como evento `sessionExpired`.
    self?.notifyJSSessionExpired()
}

ReactNativeHostManager.shared.initialize()
```

> El orden importa: `provider` y `appConfig` deben estar seteados **antes** de que el runtime de RN levante. Si `provider` queda `nil`, el módulo RN cae al `MockNetworkProvider` JS — útil para builds con backend stubbed.

---

## Versionado

| Aspecto | Detalle |
|---|---|
| Manifestos | `Package.swift` + `NetworkContracts.podspec` apuntando al mismo `Sources/` |
| Resolución | Git tag (SPM lee el tag directo; el podspec usa `:tag => s.version.to_s`) |
| Sincronización con Android | Mismo `MAJOR.MINOR` siempre. Patches pueden divergir si son fixes específicos de iOS |
| Cambios al contrato | Requieren PR simultáneo en [`rn-network-contracts-android`](https://bitbucket.scotiabank.com/projects/<PROJECT>/repos/rn-network-contracts-android) con el mismo bump |

Ver [CHANGELOG.md](./CHANGELOG.md) para el historial.

---

## Desarrollo

```bash
swift build              # compila la librería
swift test               # corre los tests
pod lib lint NetworkContracts.podspec --allow-warnings   # valida el podspec
```

Los tres tienen que pasar localmente antes de abrir un PR. El Jenkinsfile en el repo corre exactamente lo mismo.

## Estructura

```
.
├── Jenkinsfile
├── NetworkContracts.podspec
├── Package.swift
├── README.md
├── CHANGELOG.md
├── Sources/
│   └── NetworkContracts/
│       ├── AppConfig.swift
│       ├── NetworkError.swift
│       ├── NetworkProvider.swift
│       ├── NetworkResponse.swift
│       └── RNNetworkRegistry.swift
└── Tests/
    └── NetworkContractsTests/
        └── NetworkContractsTests.swift
```
