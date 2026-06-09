# rn-network-contracts

Contrato formal entre las apps nativas de Scotia y `@scotia/rn-network`. Define los tipos que los hosts iOS (Swift) y Android (Kotlin) implementan para que el módulo React Native enrute requests a través del stack HTTP del banco (pinning, sesión, telemetría).

Librería binaria, sin dependencias externas, sin importar React Native ni Expo. La consumen:

- La **app nativa del banco** (que **provee** la implementación del `NetworkProvider`).
- El **módulo Expo** `@scotia/rn-network` (que la **consume** vía el singleton `RNNetworkRegistry`).

---

## Este repo es el prototipo combinado (iOS + Android)

En **Scotia** el contrato se separa en **dos repositorios independientes**, uno por plataforma:

| Plataforma | Repo en Scotia | README | Distribución |
|---|---|---|---|
| iOS (Swift) | `rn-network-contracts-ios` | **[README-ios.md](README-ios.md)** | xcframework binario (SPM + CocoaPods) |
| Android (Kotlin) | `rn-network-contracts-android` | **[README-android.md](README-android.md)** | AAR (Maven interno) |

> Acá conviven ambas plataformas (`ios/` + `android/`) para desarrollo. Al migrar a Scotia, cada carpeta va a su propio repo y los `Sources`/`src` suben a la raíz (sin el prefijo de plataforma).

---

## Estructura del prototipo

```
rn-network-contracts/
├── Package.swift                 ← SPM (source) para build del xcframework + tests
├── scripts/
│   ├── build-xcframework.sh      ← genera el xcframework iOS
│   └── build-and-sync.sh         ← build + sync al módulo Expo (dev local)
├── fastlane/ , Jenkinsfile , Gemfile   ← pipeline iOS (release del xcframework)
├── ios/Sources/iOSNetworkContract/     ← contrato Swift
├── ios/Tests/iOSNetworkContractTests/
├── android/                            ← contrato Kotlin + build.gradle
├── README-ios.md                       ← guía iOS
└── README-android.md                   ← guía Android
```

---

## Tipos del contrato (ambas plataformas)

| Tipo | Rol |
|---|---|
| `NetworkProvider` | El host lo implementa. `request(requestId, url, method, headers, body) → NetworkResponse` + `cancel` opcional |
| `NetworkResponse` | Envelope de éxito: `statusCode`, `headers`, `data?` |
| `NetworkError` | Error tipado del host (`SESSION_EXPIRED`, `RATE_LIMITED`, …) |
| `AppConfig` / `DomainConfig` | Dominios disponibles (inmutable) |
| `RNNetworkRegistry` | Singleton: `provider`, `appConfig`, `activeDomain`, `onSessionExpired` |

Las firmas Swift y Kotlin son equivalentes y se versionan en lockstep (mismo `MAJOR.MINOR`).

---

## Por dónde empezar

- **Integrar en iOS:** [README-ios.md](README-ios.md)
- **Integrar en Android:** [README-android.md](README-android.md)
- **Documentación completa** (arquitectura, decisiones, troubleshooting): ver `docs/` en el repo de [`@scotia/rn-network`](../rn-network/docs/README.md)

## Estado

| | iOS | Android |
|---|---|---|
| Contrato + docs | ✅ | ✅ |
| Build real validado | ✅ probado en device | ❌ pendiente (primer build del dev Android) |
