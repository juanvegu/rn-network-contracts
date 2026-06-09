# iOSNetworkContract (rn-network-contracts-ios)

Swift contract that Scotia's native iOS app implements so the Expo module `@scotia/rn-network` can route its HTTP requests through the bank's stack (URLSession with pinning, session, telemetry).

Binary repo, zero external dependencies, does not import React Native or Expo.

> **Sibling repo (Android):** `rn-network-contracts-android`. Both go to the same `MAJOR.MINOR`.

---

## Distribution: source (SPM) or binary (xcframework)

The contract is **dual-capable**:

- **Source via SPM** — the `Package.swift` compiles the `.swift` files directly. Works for a standalone SPM consumer.
- **Binary via xcframework** — a prebuilt `.xcframework`, consumable by SPM (`.binaryTarget`) **and** CocoaPods (`vendored_frameworks`).

**We use the binary (xcframework), not source.** This is NOT because SPM is broken — it's due to an **Expo/React Native ecosystem limitation**:

- Expo Modules are tied to CocoaPods (ExpoModulesCore, autolinking, brownfield)
- No native SPM support in Expo yet (RN 0.84+ roadmap; SDK 56 experimental)
- The `cocoapods-spm` plugin is banned by bank security

To share a **single instance** of `RNNetworkRegistry` between the native app (SPM) and the Expo module (CocoaPods), both must point to the **same binary**. Source-on-both-sides would mean two compilations → two singletons → broken contract.

**When to revert to source:** once Expo/RN support SPM first-class. Until then, binary.

---

## Public types

| Type | Description |
|---|---|
| `NetworkProvider` | Protocol the host implements. `request(requestId:url:method:headers:body:) async throws -> NetworkResponse` + optional `cancel(requestId:)` |
| `NetworkResponse` | Success envelope: `statusCode`, `headers`, `data?` |
| `NetworkError` | Host's typed error: `code`, `retryable`, `httpStatus?`, `message?`, `info?` |
| `AppConfig` / `DomainConfig` | Immutable description of available domains |
| `RNNetworkRegistry` | Singleton: `provider`, `appConfig`, `activeDomain`, `onSessionExpired` |

### When to throw vs return

| Situation | Host action |
|---|---|
| HTTP 2xx | `NetworkResponse(statusCode: 200, headers:, data: bytes)` |
| HTTP 204 | `NetworkResponse(statusCode: 204, data: nil)` |
| HTTP non-2xx | **Do NOT classify** — return the response; the RN module classifies |
| Domain failure (session, biometrics) | `throw NetworkError(code: "SESSION_EXPIRED", …)` |
| Timeout / SSL / connectivity / cancel | Let `URLError` / `CancellationError` propagate |

---

## Consuming the xcframework

### Native app (SPM)

```swift
// Production — Package.swift, snippet from the published DISTRIBUTION.md
.binaryTarget(
    name: "iOSNetworkContract",
    url: "https://artifactory.scotiabank.cl/ios/iOSNetworkContract/1.1.0/iOSNetworkContract.xcframework.zip",
    checksum: "<sha256>"
)

// Local dev — path to the local build
.binaryTarget(name: "iOSNetworkContract", path: "../rn-network-contracts/build/iOSNetworkContract.xcframework")
```

### Expo module (CocoaPods, vendored)

The `@scotia/rn-network` module bundles the xcframework. See its podspec (`vendored_frameworks` + `user_target_xcconfig`).

---

## Implementing the provider

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

    func cancel(requestId: String) { /* find the URLSessionTask and .cancel() */ }
}
```

## Registering before RN starts

```swift
import iOSNetworkContract

RNNetworkRegistry.appConfig = AppConfig(
    country: "CL", environment: "prod",
    domains: [DomainConfig(key: "BFF", baseURL: "https://api.bank.cl")]
)
RNNetworkRegistry.activeDomain = "BFF"
RNNetworkRegistry.provider = AppNetworkProvider()        // if nil → RN falls back to the JS mock
RNNetworkRegistry.onSessionExpired = { /* notify JS */ }

ReactNativeHostManager.shared.initialize()               // ALWAYS last
```

---

## Development

```bash
swift build                          # compile the library (source)
swift test                           # tests
./scripts/build-xcframework.sh       # generate the xcframework
./scripts/build-and-sync.sh          # build + sync to the Expo module (local dev)
```

## Release (Fastlane + Jenkins)

```bash
fastlane test                        # swift build + test
fastlane build_xcframework           # generate the binary without publishing
fastlane release bump:minor          # bump tag + build + upload + DISTRIBUTION.md
```

The pipeline (manual from Jenkins) versions by **git tag**, generates the xcframework with `build-xcframework.sh`, uploads it to Artifactory, and writes `DISTRIBUTION.md` with the URL + checksum.

> We do NOT use `fastlane-plugin-create_xcframework` — it fails with pure Swift Packages (deprecated bitcode + a framework with no `Modules/swiftinterface`). The script handles the SwiftPM gotchas.

## Structure (iOS-only repo at the bank)

```
rn-network-contracts-ios/
├── Package.swift                     ← source, for the build script + tests
├── scripts/
│   ├── build-xcframework.sh
│   └── build-and-sync.sh
├── Sources/iOSNetworkContract/       ← no ios/ prefix (iOS-only repo)
├── Tests/iOSNetworkContractTests/
├── fastlane/Fastfile
├── Jenkinsfile
└── Gemfile
```

> In the combined prototype (iOS+Android), Sources live under `ios/Sources/...`. When splitting into the bank's iOS-only repo, they move up to the root (`Sources/...`) and the `ios/` prefix is removed from the `Package.swift` `path:` entries.

## Versioning

- **Version = git tag.** No podspec to bump.
- The native app and the Expo module must use the **same version** of the xcframework (otherwise `Symbol not found` at runtime).
- iOS ↔ Android go to the same `MAJOR.MINOR`.
