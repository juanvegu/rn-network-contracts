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

### Distribución vía JitPack

El contracts module se publica como AAR en [JitPack](https://jitpack.io/) directamente desde GitHub — mismo modelo que el pod en iOS. Coordenadas:

```
com.github.juanvegu:rn-network-contracts:<tag>
```

La versión Android va siempre alineada con el podspec iOS (mismo tag).

#### 1. Habilitar el repo de JitPack en el host

`settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

#### 2. Declarar la dependencia en host y expo-module

Ambos lados deben referenciar la **misma versión**. Una versión en común garantiza que el APK final tenga un único `RNNetworkRegistry` y que el patrón singleton funcione.

```kotlin
// scotia-android-native/app/build.gradle.kts
dependencies {
    implementation("com.github.juanvegu:rn-network-contracts:1.0.7")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
```

```groovy
// rn-network/android/build.gradle (expo-module)
repositories { maven { url 'https://jitpack.io' } }
dependencies { implementation 'com.github.juanvegu:rn-network-contracts:1.0.7' }
```

#### 3. Implementar un `NetworkProvider` regional (OkHttp + pinning)

```kotlin
import com.scotia.rnnetwork.contracts.NetworkProvider
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class AppNetworkProvider : NetworkProvider {
    private val client = OkHttpClient.Builder()
        .certificatePinner(
            CertificatePinner.Builder()
                .add("api.bank.cl", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
                .build()
        )
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override suspend fun request(
        url: String, method: String,
        headers: Map<String, String>, body: Map<String, Any?>?
    ): ByteArray = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
        val req = Request.Builder().url(url).apply {
            headers.forEach { (k, v) -> header(k, v) }
            val rb = body?.let { JSONObject(it).toString().toRequestBody("application/json".toMediaType()) }
            method(method.uppercase(), rb)
        }.build()
        client.newCall(req).execute().use { resp ->
            val bytes = resp.body?.bytes() ?: ByteArray(0)
            if (!resp.isSuccessful) throw java.io.IOException("com.scotia.rnnetwork.http:${resp.code}")
            bytes
        }
    }
}
```

> **Pin format:** `sha256/<base64-de-SPKI>`. Se calcula con
> `openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | openssl base64`.

#### 4. Registrar antes de inicializar RN

```kotlin
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        RNNetworkRegistry.provider = AppNetworkProvider()
        RNNetworkRegistry.appConfig = mapOf(
            "country" to "CL",
            "domains" to listOf(mapOf("key" to "prod", "baseURL" to "https://api.bank.cl")),
            "activeDomain" to "prod",
        )
        Log.d("Net", "host id=${System.identityHashCode(RNNetworkRegistry)} cl=${RNNetworkRegistry::class.java.classLoader}")
        ReactNativeHostManager.initialize(this)  // SIEMPRE después del register
    }
}
```

#### 5. Verificación de identidad de instancia

A diferencia de iOS no hay riesgo de "framework duplicado" — la JVM tiene un único `ClassLoader` por proceso. Pero confirmar igual con un `Function("debugIdentity")` en el expo-module y un `Log.d` desde el host. Mismo `identityHashCode` y mismo `ClassLoader` en ambos lados ⇒ singleton compartido.

#### Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| `Could not resolve com.github.juanvegu:rn-network-contracts:X` | Falta el repo JitPack o el tag aún no se construyó | Añadir `maven { url 'https://jitpack.io' }` en `settings.gradle.kts`. Verificar https://jitpack.io/com/github/juanvegu/rn-network-contracts/X/. |
| `Type com.scotia...RNNetworkRegistry is defined multiple times` | El contract entró por dos rutas (composite build + Maven) | Unificar a una sola fuente (solo JitPack). |
| `provider == null` aunque registraste | Orden: `register` después del init de RN | Mover `RNNetworkRegistry.provider = ...` antes de `ReactNativeHostManager.initialize`. |
| `SSLPeerUnverifiedException: Certificate pinning failure!` | Pin mal calculado / cert rotado | Recalcular con el snippet `openssl`. |
| Versión inconsistente entre host y expo-module | Resolución de Gradle elige una | Pin explícito en ambos lados a la misma `<tag>` y verificar con `./gradlew :app:dependencyInsight --dependency rn-network-contracts`. |

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
