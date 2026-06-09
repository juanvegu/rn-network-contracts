# rn-network-contracts

Formal contract between Scotia's native apps and `@scotia/rn-network`. Defines the types that iOS (Swift) and Android (Kotlin) hosts implement so the React Native module can route requests through the bank's HTTP stack (pinning, session, telemetry).

Binary library, zero external dependencies, does not import React Native or Expo. Consumed by:

- The **bank's native app** (which **provides** the `NetworkProvider` implementation).
- The **Expo module** `@scotia/rn-network` (which **consumes** it via the `RNNetworkRegistry` singleton).

---

## This repo is the combined prototype (iOS + Android)

At **Scotia** the contract splits into **two independent repositories**, one per platform:

| Platform | Scotia repo | README | Distribution |
|---|---|---|---|
| iOS (Swift) | `rn-network-contracts-ios` | **[README-ios.en.md](README-ios.en.md)** | binary xcframework (SPM + CocoaPods) |
| Android (Kotlin) | `rn-network-contracts-android` | **[README-android.en.md](README-android.en.md)** | AAR (internal Maven) |

> Here both platforms (`ios/` + `android/`) coexist for development. When migrating to Scotia, each folder goes to its own repo and the `Sources`/`src` move up to the root (no platform prefix).

---

## Prototype structure

```
rn-network-contracts/
├── Package.swift                 ← SPM (source) for the xcframework build + tests
├── scripts/
│   ├── build-xcframework.sh      ← generates the iOS xcframework
│   └── build-and-sync.sh         ← build + sync to the Expo module (local dev)
├── fastlane/ , Jenkinsfile , Gemfile   ← iOS pipeline (xcframework release)
├── ios/Sources/iOSNetworkContract/     ← Swift contract
├── ios/Tests/iOSNetworkContractTests/
├── android/                            ← Kotlin contract + build.gradle
├── README-ios.en.md                    ← iOS guide
└── README-android.en.md                ← Android guide
```

---

## Contract types (both platforms)

| Type | Role |
|---|---|
| `NetworkProvider` | Host implements it. `request(requestId, url, method, headers, body) → NetworkResponse` + optional `cancel` |
| `NetworkResponse` | Success envelope: `statusCode`, `headers`, `data?` |
| `NetworkError` | Host's typed error (`SESSION_EXPIRED`, `RATE_LIMITED`, …) |
| `AppConfig` / `DomainConfig` | Available domains (immutable) |
| `RNNetworkRegistry` | Singleton: `provider`, `appConfig`, `activeDomain`, `onSessionExpired` |

The Swift and Kotlin signatures are equivalent and versioned in lockstep (same `MAJOR.MINOR`).

---

## Where to start

- **Integrate on iOS:** [README-ios.en.md](README-ios.en.md)
- **Integrate on Android:** [README-android.en.md](README-android.en.md)
- **Full documentation** (architecture, decisions, troubleshooting): see `docs/` in the [`@scotia/rn-network`](../rn-network/docs/README.md) repo

## Status

| | iOS | Android |
|---|---|---|
| Contract + docs | ✅ | ✅ |
| Real build validated | ✅ tested on device | ❌ pending (Android dev's first build) |
