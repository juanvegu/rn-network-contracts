import XCTest
@testable import NetworkContracts

final class NetworkContractsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Limpiar estado del singleton entre tests para evitar pollution.
        RNNetworkRegistry.provider = nil
        RNNetworkRegistry.appConfig = nil
        RNNetworkRegistry.activeDomain = nil
        RNNetworkRegistry.onSessionExpired = nil
    }

    // MARK: AppConfig

    func test_appConfig_carriesDomains() {
        let config = AppConfig(
            country: "CL",
            environment: "test",
            domains: [
                DomainConfig(key: "BFF", baseURL: "https://api.bank.cl"),
                DomainConfig(key: "INSURANCE", baseURL: "https://insurance.bank.cl"),
            ]
        )

        XCTAssertEqual(config.country, "CL")
        XCTAssertEqual(config.environment, "test")
        XCTAssertEqual(config.domains.count, 2)
        XCTAssertEqual(config.domains[0].key, "BFF")
        XCTAssertEqual(config.domains[1].baseURL, "https://insurance.bank.cl")
    }

    // MARK: NetworkError

    func test_networkError_carriesAllFields() {
        let error = NetworkError(
            code: "RATE_LIMITED",
            retryable: true,
            httpStatus: 429,
            message: "Too many requests",
            info: ["retryAfter": 30]
        )

        XCTAssertEqual(error.code, "RATE_LIMITED")
        XCTAssertTrue(error.retryable)
        XCTAssertEqual(error.httpStatus, 429)
        XCTAssertEqual(error.message, "Too many requests")
        XCTAssertEqual(error.info?["retryAfter"] as? Int, 30)
    }

    func test_networkError_defaults() {
        let error = NetworkError(code: "UNKNOWN")
        XCTAssertEqual(error.code, "UNKNOWN")
        XCTAssertFalse(error.retryable)
        XCTAssertNil(error.httpStatus)
        XCTAssertNil(error.message)
        XCTAssertNil(error.info)
    }

    // MARK: NetworkResponse

    func test_networkResponse_with204_hasNilData() {
        let response = NetworkResponse(statusCode: 204, headers: [:], data: nil)
        XCTAssertEqual(response.statusCode, 204)
        XCTAssertNil(response.data)
    }

    func test_networkResponse_with200_hasBody() {
        let body = "{\"ok\":true}".data(using: .utf8)
        let response = NetworkResponse(
            statusCode: 200,
            headers: ["X-Trace-Id": "abc"],
            data: body
        )
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["X-Trace-Id"], "abc")
        XCTAssertEqual(response.data, body)
    }

    // MARK: RNNetworkRegistry

    func test_registry_activeBaseURL_isNilWhenUnset() {
        XCTAssertNil(RNNetworkRegistry.activeBaseURL)
    }

    func test_registry_activeBaseURL_derivesFromActiveDomain() {
        RNNetworkRegistry.appConfig = AppConfig(
            country: "CL",
            environment: "prod",
            domains: [
                DomainConfig(key: "BFF", baseURL: "https://api.bank.cl"),
                DomainConfig(key: "INSURANCE", baseURL: "https://insurance.bank.cl"),
            ]
        )
        RNNetworkRegistry.activeDomain = "INSURANCE"

        XCTAssertEqual(RNNetworkRegistry.activeBaseURL, "https://insurance.bank.cl")
    }

    func test_registry_activeBaseURL_isNilForUnknownActiveDomain() {
        RNNetworkRegistry.appConfig = AppConfig(
            country: "CL",
            environment: "prod",
            domains: [DomainConfig(key: "BFF", baseURL: "https://api.bank.cl")]
        )
        RNNetworkRegistry.activeDomain = "NONEXISTENT"

        XCTAssertNil(RNNetworkRegistry.activeBaseURL)
    }

    // MARK: NetworkProvider default cancel

    func test_networkProvider_defaultCancel_isNoOp() {
        // Implementación mínima que NO override `cancel`.
        struct DummyProvider: NetworkProvider {
            func request(requestId: String, url: String, method: String,
                         headers: [String: String], body: [String: Any]?) async throws -> NetworkResponse {
                NetworkResponse(statusCode: 200, headers: [:], data: nil)
            }
        }

        let provider = DummyProvider()
        // No debe tirar ni crashear.
        provider.cancel(requestId: "any-id")
    }
}
