# rn-network-contracts

Formal contract between Scotia's native banking apps and `@scotia/rn-network`. Defines the types iOS (SPM + CocoaPods) and Android (Gradle/Maven) hosts must implement so the React Native module can perform network requests through the host's existing HTTP stack (with its pinning, session, telemetry).

The library is binary-stable, has zero external dependencies, does not import React Native or Expo, and is consumed identically by:

- The bank's native app (which **provides** the implementation).
- The RN Expo module (which **consumes** it through a singleton registry).

---

## Architecture in one diagram

```
┌──────────────────────────┐         ┌──────────────────────────────┐
│  Bank's native app       │         │ @scotia/rn-network (Expo)    │
│                          │         │                              │
│  AppNetworkProvider  ────┼─── via ─┼─►  RNNetworkBridge (JS) ─►   │
│  (URLSession / OkHttp)   │ Registry│      request(url, …)         │
│                          │         │                              │
│  RNNetworkRegistry.shared          │  RnNetworkModule (Swift/Kt)  │
│   ├─ provider                      │   ├─ enforces 2xx            │
│   ├─ appConfig                     │   ├─ surfaces statusCode +   │
│   ├─ activeDomain                  │   │  headers to JS           │
│   └─ onSessionExpired              │   └─ emits sessionExpired    │
└──────────────────────────┘         └──────────────────────────────┘
```

The bank assigns `RNNetworkRegistry.provider` **before** initializing React Native. If it doesn't, the RN side falls back to its JS `MockNetworkProvider` (useful when the host runs in stubbed/mock mode while contracts are still being built).

---

## Public types

| Type | Purpose |
|---|---|
| `NetworkProvider` | The interface a host implements to perform requests. One method (`request`) plus an optional `cancel`. |
| `NetworkResponse` | Envelope returned on success: `statusCode`, `headers`, `data`. |
| `NetworkError` | Typed error a host may throw to communicate domain-specific failures (`SESSION_EXPIRED`, `RATE_LIMITED`, etc.). |
| `AppConfig` | Static description of the available domains for the RN flow (`country`, `environment`, `domains`). Immutable. |
| `DomainConfig` | `{ key, baseURL }` entry inside `AppConfig.domains`. |
| `RNNetworkRegistry` | Singleton the host populates: `provider`, `appConfig`, `activeDomain`, `onSessionExpired`. |

### Why an envelope on success?

`request(...)` returns a `NetworkResponse` instead of raw `Data`/`ByteArray` so the RN module can:

1. **Enforce the 2xx rule centrally** — the host never has to remember to throw for non-2xx; the module classifies based on `statusCode`.
2. **Surface metadata to JS** — `Retry-After`, `X-Trace-Id`, etc. are reachable from React without round-tripping.
3. **Handle 204/empty bodies cleanly** — `data` is `nil`/`null`, no JSON parse attempted.

### When should the host throw?

| Situation | Host action |
|---|---|
| HTTP 2xx | Return `NetworkResponse(statusCode: 200, headers: …, data: bytes)` |
| HTTP 204 | Return `NetworkResponse(statusCode: 204, headers: …, data: nil)` |
| HTTP non-2xx | **Don't classify** — return the response as-is; the module handles it |
| Domain-specific failure (e.g. session expired) | `throw NetworkError(code: "SESSION_EXPIRED", …)` |
| Network timeout / connectivity / SSL | Let the underlying error propagate; the RN mapper translates it |
| Coroutine/Task cancelled | Let `CancellationException`/`CancellationError` propagate |

---

## Standard error codes

The RN module guarantees these codes reach JS. Hosts may define their own (prefix recommended: `SCOTIA_KYC_PENDING`, `SCOTIA_BIOMETRIC_REQUIRED`, …).

| Code | Source | `retryable` | Notes |
|---|---|---|---|
| `SSL_PINNING_FAILED` | mapper | false | Cert mismatch / chain failure |
| `TIMEOUT` | mapper or JS client timeout | true | Server didn't respond in time |
| `NO_CONNECTIVITY` | mapper | true | Airplane mode, DNS failure |
| `HTTP_CLIENT_ERROR` | module (4xx) | false | Module assigns automatically |
| `HTTP_SERVER_ERROR` | module (5xx) | true | Module assigns automatically |
| `INVALID_RESPONSE_BODY` | module | false | 2xx with non-JSON body |
| `CANCELLED` | mapper | false | Task/coroutine cancellation |
| `SESSION_EXPIRED` | host | false | Returning user, session no longer valid |
| `SESSION_UNAUTHORIZED` | host | false | 401 that is not expiration (bad credentials) |
| `PROVIDER_NOT_SET` | module | false | No host provider registered AND no JS fallback |
| `UNKNOWN` | mapper | false | Unmapped error |

---

## iOS

### Installation

The repo ships **both** Swift Package Manager and CocoaPods manifests pointing at the same `Sources/`. Choose whichever your project uses.

```swift
// Package.swift consumer
.package(url: "https://github.scotiabank.com/<org>/rn-network-contracts-ios.git", from: "1.0.0")
```

```ruby
# Podfile consumer
pod 'NetworkContracts', '~> 1.0.0'
```

> Expo Modules currently consumes via CocoaPods. Scotia native apps migrating to SPM can use the SPM manifest directly without affecting the RN module.

### Implementing the contract

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

        // Domain-specific signal: the bank decides which 401 is "session gone".
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
        // Optional. Look up the URLSessionTask by requestId and call .cancel() on it.
    }
}
```

### Registering before RN starts

```swift
// AppDelegate (or wherever RN is bootstrapped)
import NetworkContracts

RNNetworkRegistry.provider = AppNetworkProvider()
RNNetworkRegistry.appConfig = AppConfig(
    country: "CL",
    environment: "prod",
    domains: [DomainConfig(key: "BFF", baseURL: "https://api.bank.cl")]
)
RNNetworkRegistry.activeDomain = "BFF"

// Notify the JS side when the session is lost (e.g. token refresh failed).
RNNetworkRegistry.onSessionExpired = { [weak self] in
    self?.notifySessionExpired()
}

ReactNativeHostManager.shared.initialize()
```

> The order matters: `provider` and `appConfig` must be set **before** RN initializes. If `provider` is left `nil`, the RN module falls back to its JS `MockNetworkProvider` — useful for staged rollouts where the native HTTP stack isn't ready yet.

---

## Android

### Installation

The repo publishes an AAR to Scotia's internal Maven registry. Add the registry and the dependency:

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://nexus.scotiabank.cl/repository/maven-releases/")
            credentials {
                username = providers.gradleProperty("scotiaNexusUser").get()
                password = providers.gradleProperty("scotiaNexusPass").get()
            }
        }
    }
}
```

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("cl.scotiabank.rnnetwork:contracts:1.0.0")
}
```

Both the bank's host app **and** the `rn-network` Expo module must depend on the **same version** of contracts to guarantee a single `RNNetworkRegistry` instance in the APK.

### Implementing the contract

```kotlin
import com.scotia.rnnetwork.contracts.NetworkError
import com.scotia.rnnetwork.contracts.NetworkProvider
import com.scotia.rnnetwork.contracts.NetworkResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class AppNetworkProvider(
    private val client: OkHttpClient,
) : NetworkProvider {

    override suspend fun request(
        requestId: String,
        url: String,
        method: String,
        headers: Map<String, String>,
        body: Map<String, Any?>?,
    ): NetworkResponse = withContext(Dispatchers.IO) {
        val req = Request.Builder().url(url).apply {
            headers.forEach { (k, v) -> header(k, v) }
            val rb = body?.let {
                JSONObject(it).toString().toRequestBody("application/json".toMediaType())
            }
            method(method.uppercase(), rb)
            tag(requestId)   // enables cancel(requestId) lookup
        }.build()

        client.newCall(req).execute().use { resp ->
            // Domain-specific signal.
            if (resp.code == 401 && resp.header("X-Session-Expired") == "true") {
                throw NetworkError(code = "SESSION_EXPIRED", retryable = false, httpStatus = 401)
            }

            val bytes = resp.body?.bytes()?.takeIf { it.isNotEmpty() }
            val headerMap = resp.headers.toMultimap()
                .mapValues { it.value.joinToString(", ") }
            NetworkResponse(
                statusCode = resp.code,
                headers = headerMap,
                data = if (resp.code == 204) null else bytes,
            )
        }
    }

    override fun cancel(requestId: String) {
        client.dispatcher.queuedCalls().firstOrNull { it.request().tag() == requestId }?.cancel()
        client.dispatcher.runningCalls().firstOrNull { it.request().tag() == requestId }?.cancel()
    }
}
```

### Registering before RN starts

```kotlin
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        RNNetworkRegistry.provider = AppNetworkProvider(buildOkHttpClient())
        RNNetworkRegistry.appConfig = AppConfig(
            country = "CL",
            environment = "prod",
            domains = listOf(DomainConfig(key = "BFF", baseURL = "https://api.bank.cl")),
        )
        RNNetworkRegistry.activeDomain = "BFF"

        RNNetworkRegistry.onSessionExpired = {
            // Triggered when host detects the session is gone.
            // The RN module forwards this to JS as a `sessionExpired` event.
            notifySessionExpired()
        }

        ReactNativeHostManager.initialize(this)
    }
}
```

---

## Full RN scenarios (no native provider)

Some apps (or QA builds) intentionally don't ship a native provider. The RN module detects the absence and falls back to a JS `MockNetworkProvider` set by the app:

```typescript
import { setProvider, isAvailable, MockNetworkProvider } from '@scotia/rn-network'

if (!isAvailable()) {
  setProvider(new MockNetworkProvider({
    routes: {
      'GET /v1/brands': require('./mocks/brands.json'),
      'POST /v1/quote': { code: 'SESSION_EXPIRED', retryable: false }, // throws
    },
  }))
}
```

The rule is binary: **provider registered → use it; not registered → use the JS mock.** There is no `__DEV__` gate; the host decides.

---

## Version policy

| Repo | Manifest | Resolution |
|---|---|---|
| `rn-network-contracts-ios` | `Package.swift` + `NetworkContracts.podspec` | Git tag |
| `rn-network-contracts-android` | `build.gradle` (`maven-publish`) | Maven coords `cl.scotiabank.rnnetwork:contracts:<version>` |

Both repos go together on `MAJOR.MINOR`. Patches may drift if they are platform-specific fixes. Any change that touches the contract surface (signatures, registry fields) opens **two PRs simultaneously**, one per repo, with the same version bump in both `CHANGELOG.md`.
