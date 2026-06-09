# rn-network-contracts-android

Contrato Kotlin que la app nativa Android de Scotia implementa para que el módulo Expo `@scotia/rn-network` enrute sus requests HTTP a través del stack del banco (OkHttp con pinning, sesión, telemetría).

Librería binaria (AAR), sin dependencias externas, sin importar React Native ni Expo.

> **Repo hermano (iOS):** `rn-network-contracts-ios`. Ambos van al mismo `MAJOR.MINOR`.
>
> **⚠️ Estado:** el contrato Kotlin está escrito y la integración documentada, pero **el flujo Android no se validó todavía en un build real** (a diferencia de iOS, probado en device). Esperá posibles gotchas de Gradle/autolinking/brownfield en el primer build. Ver la sección [Estado](#estado).

---

## Distribución: AAR vía Maven

A diferencia de iOS, Android **no necesita xcframework**. Gradle dedupea por coordenada Maven — un solo `RNNetworkRegistry` en el APK mientras host y módulo usen la misma versión. No hay problema de doble singleton como en iOS (SPM + CocoaPods).

```
cl.scotiabank.rnnetwork:contracts:1.1.0    (AAR en el Maven interno de Scotia)
```

---

## Tipos públicos

| Tipo | Descripción |
|---|---|
| `NetworkProvider` | Interface que el host implementa. `suspend request(requestId, url, method, headers, body): NetworkResponse` + `cancel(requestId)` opcional |
| `NetworkResponse` | Envelope de éxito: `statusCode`, `headers`, `data: ByteArray?` |
| `NetworkError` | Excepción tipada del host: `code`, `retryable`, `httpStatus?`, `message?`, `info?` |
| `AppConfig` / `DomainConfig` | Descripción inmutable de dominios |
| `RNNetworkRegistry` | Singleton: `provider`, `appConfig`, `activeDomain`, `onSessionExpired` |

### Cuándo lanzar vs retornar

| Situación | Acción del host |
|---|---|
| HTTP 2xx | `NetworkResponse(statusCode = 200, headers, data = bytes)` |
| HTTP 204 | `NetworkResponse(statusCode = 204, data = null)` |
| HTTP non-2xx | **NO clasificar** — retornar la response; el módulo RN clasifica |
| Falla de dominio | `throw NetworkError(code = "SESSION_EXPIRED", …)` |
| Timeout / SSL / connectivity / cancel | Dejar propagar `IOException` / `SSLException` / `CancellationException` |

---

## Consumir

```kotlin
// settings.gradle.kts — habilitar el Maven interno
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

La app nativa **y** el módulo Expo (`rn-network/android/build.gradle`) deben usar la **misma versión**.

---

## Implementar el provider (OkHttp + pinning)

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
            tag(requestId)   // para cancel(requestId)
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

## Registrar antes de iniciar RN

```kotlin
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        RNNetworkRegistry.appConfig = AppConfig(
            country = "CL", environment = "prod",
            domains = listOf(DomainConfig("BFF", "https://api.bank.cl")),
        )
        RNNetworkRegistry.activeDomain = "BFF"
        RNNetworkRegistry.provider = AppNetworkProvider(buildOkHttp())   // si null → RN cae al mock JS
        RNNetworkRegistry.onSessionExpired = { /* notificar al JS */ }

        ReactNativeHostManager.initialize(this)   // SIEMPRE al final
    }
}
```

---

## Desarrollo

```bash
./gradlew build                  # compila + lint
./gradlew test                   # tests unitarios
./gradlew publishToMavenLocal    # publica a ~/.m2 para probar contra un consumidor
```

## Publicación (Maven)

```bash
./gradlew publish \
  -PscotiaNexusUser=$SCOTIA_NEXUS_USER \
  -PscotiaNexusPass=$SCOTIA_NEXUS_PASS
git tag 1.1.0 && git push origin 1.1.0
```

## Estructura

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

> **Coordenadas Maven:** el prototipo usa `com.github.juanvegu`. Al migrar al banco, cambiar a `cl.scotiabank.rnnetwork:contracts` (confirmar con DevOps).

## Estado

| | iOS | Android |
|---|---|---|
| Código del contrato | ✅ | ✅ |
| Docs | ✅ | ✅ |
| **Build real validado** | ✅ probado en device | ❌ **pendiente** |

Lo que el dev Android debe validar en el primer build:

- Gradle wrapper + resolución del AAR (los problemas de proxy/wrapper que quedaron pendientes)
- `metro.config.js` en la app — es el **lado JS compartido**, el mismo issue que se resolvió en iOS aplica acá
- El `android/build.gradle` del módulo Expo resolviendo la dependencia Maven del contrato
- El brownfield Android build (equivalente al `ScotiaBrownfield.framework`, pero AAR)

Android es **conceptualmente más simple** que iOS (sin la dualidad SPM/CocoaPods, sin xcframework), así que el riesgo de gotchas es menor — pero no cero.

## Versionado

- iOS ↔ Android van al mismo `MAJOR.MINOR`. Cambio del contrato → PRs espejo.
- La app nativa y el módulo Expo deben usar la **misma versión** del AAR.
