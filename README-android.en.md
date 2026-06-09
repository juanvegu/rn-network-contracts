# rn-network-contracts-android

Kotlin contract that Scotia's native Android app implements so the Expo module `@scotia/rn-network` can route its HTTP requests through the bank's stack (OkHttp with pinning, session, telemetry).

Binary library (AAR), zero external dependencies, does not import React Native or Expo.

> **Sibling repo (iOS):** `rn-network-contracts-ios`. Both go to the same `MAJOR.MINOR`.
>
> **⚠️ Status:** the Kotlin contract is written and the integration documented, but **the Android flow has not been validated in a real build yet** (unlike iOS, validated on device). Expect possible Gradle/autolinking/brownfield gotchas on the first build. See [Status](#status).

---

## Distribution: AAR via Maven

Unlike iOS, Android **does not need an xcframework**. Gradle deduplicates by Maven coordinate — a single `RNNetworkRegistry` in the APK as long as host and module use the same version. There is no duplicate-singleton problem like iOS (SPM + CocoaPods).

```
cl.scotiabank.rnnetwork:contracts:1.1.0    (AAR in Scotia's internal Maven)
```

---

## Public types

| Type | Description |
|---|---|
| `NetworkProvider` | Interface the host implements. `suspend request(requestId, url, method, headers, body): NetworkResponse` + optional `cancel(requestId)` |
| `NetworkResponse` | Success envelope: `statusCode`, `headers`, `data: ByteArray?` |
| `NetworkError` | Host's typed exception: `code`, `retryable`, `httpStatus?`, `message?`, `info?` |
| `AppConfig` / `DomainConfig` | Immutable description of domains |
| `RNNetworkRegistry` | Singleton: `provider`, `appConfig`, `activeDomain`, `onSessionExpired` |

### When to throw vs return

| Situation | Host action |
|---|---|
| HTTP 2xx | `NetworkResponse(statusCode = 200, headers, data = bytes)` |
| HTTP 204 | `NetworkResponse(statusCode = 204, data = null)` |
| HTTP non-2xx | **Do NOT classify** — return the response; the RN module classifies |
| Domain failure | `throw NetworkError(code = "SESSION_EXPIRED", …)` |
| Timeout / SSL / connectivity / cancel | Let `IOException` / `SSLException` / `CancellationException` propagate |

---

## Consuming

```kotlin
// settings.gradle.kts — enable the internal Maven
dependencyResolutionManagement {
    repositories {
        google(); mavenCentral()
        maven {
            url = uri("https://nexus.scotiabank.cl/repository/maven-releases/")  // TODO DevOps
            credentials {
                username = providers.gradleProperty("scotiaNexusUser").get()
                password = providers.gradleProperty("scotiaNexusPass").get()
            }
        }
    }
}

// app/build.gradle.kts
dependencies {
    implementation("cl.scotiabank.rnnetwork:contracts:1.1.0")
}
```

The native app **and** the Expo module (`rn-network/android/build.gradle`) must use the **same version**.

---

## Implementing the provider (OkHttp + pinning)

```kotlin
import com.scotia.rnnetwork.contracts.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*

class AppNetworkProvider(private val client: OkHttpClient) : NetworkProvider {
    override suspend fun request(
        requestId: String, url: String, method: String,
        headers: Map<String, String>, body: Map<String, Any?>?,
    ): NetworkResponse = withContext(Dispatchers.IO) {
        val req = Request.Builder().url(url).apply {
            headers.forEach { (k, v) -> header(k, v) }
            method(method.uppercase(), body?.let { /* JSON requestBody */ null })
            tag(requestId)   // for cancel(requestId)
        }.build()

        client.newCall(req).execute().use { resp ->
            if (resp.code == 401 && resp.header("X-Session-Expired") == "true") {
                throw NetworkError(code = "SESSION_EXPIRED", retryable = false, httpStatus = 401)
            }
            val bytes = resp.body?.bytes()?.takeIf { it.isNotEmpty() }
            NetworkResponse(
                statusCode = resp.code,
                headers = resp.headers.toMultimap().mapValues { it.value.joinToString(", ") },
                data = if (resp.code == 204) null else bytes,
            )
        }
    }

    override fun cancel(requestId: String) {
        (client.dispatcher.queuedCalls() + client.dispatcher.runningCalls())
            .firstOrNull { it.request().tag() == requestId }?.cancel()
    }
}
```

## Registering before RN starts

```kotlin
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        RNNetworkRegistry.appConfig = AppConfig(
            country = "CL", environment = "prod",
            domains = listOf(DomainConfig("BFF", "https://api.bank.cl")),
        )
        RNNetworkRegistry.activeDomain = "BFF"
        RNNetworkRegistry.provider = AppNetworkProvider(buildOkHttp())   // if null → RN falls back to JS mock
        RNNetworkRegistry.onSessionExpired = { /* notify JS */ }

        ReactNativeHostManager.initialize(this)   // ALWAYS last
    }
}
```

---

## Development

```bash
./gradlew build                  # compile + lint
./gradlew test                   # unit tests
./gradlew publishToMavenLocal    # publish to ~/.m2 to test against a consumer
```

## Publishing (Maven)

```bash
./gradlew publish \
  -PscotiaNexusUser=$SCOTIA_NEXUS_USER \
  -PscotiaNexusPass=$SCOTIA_NEXUS_PASS
git tag 1.1.0 && git push origin 1.1.0
```

## Structure

```
rn-network-contracts-android/
├── build.gradle                  ← com.android.library + maven-publish
├── settings.gradle
├── gradle/wrapper/, gradlew
└── src/main/java/com/scotia/rnnetwork/contracts/
    ├── AppConfig.kt
    ├── NetworkError.kt
    ├── NetworkProvider.kt
    ├── NetworkResponse.kt
    └── RNNetworkRegistry.kt
```

> **Maven coordinates:** the prototype uses `com.github.juanvegu`. When migrating to the bank, change to `cl.scotiabank.rnnetwork:contracts` (confirm with DevOps).

## Status

| | iOS | Android |
|---|---|---|
| Contract code | ✅ | ✅ |
| Docs | ✅ | ✅ |
| **Real build validated** | ✅ tested on device | ❌ **pending** |

What the Android dev should validate on the first build:

- Gradle wrapper + AAR resolution (the proxy/wrapper issues left pending)
- `metro.config.js` in the app — it's the **shared JS side**, the same issue solved on iOS applies here
- The Expo module's `android/build.gradle` resolving the contract's Maven dependency
- The Android brownfield build (equivalent to `ScotiaBrownfield.framework`, but AAR)

Android is **conceptually simpler** than iOS (no SPM/CocoaPods duality, no xcframework), so the gotcha risk is lower — but not zero.

## Versioning

- iOS ↔ Android go to the same `MAJOR.MINOR`. Contract change → mirror PRs.
- The native app and the Expo module must use the **same version** of the AAR.
