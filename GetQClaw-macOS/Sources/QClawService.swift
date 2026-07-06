import Foundation
import Security

// MARK: - Constants

let QCLAW_APP_STORE_PATH = NSString(string: "~/Library/Application Support/QClaw/app-store.json").expandingTildeInPath
let QCLAW_API_KEY_STORE_KEY = "authGateway.providers.qclaw.apiKey"
let QCLAW_USER_INFO_STORE_KEY = "secure.userInfo"
let QCLAW_JWT_TOKEN_STORE_KEY = "secure.jwtToken"
let QCLAW_KEYCHAIN_SERVICE = "QClaw Safe Storage"
let QCLAW_KEYCHAIN_ACCOUNT = "QClaw Key"

// MARK: - Service Errors

enum ServiceError: LocalizedError {
    case appStoreNotFound(String)
    case invalidJSON
    case keychainNotFound
    case apiKeyNotFound
    case userInfoNotFound
    case noModelList
    case noBalanceData
    case noFlowData
    case noUsageData

    var errorDescription: String? {
        switch self {
        case .appStoreNotFound(let path):
            return "未找到 QClaw 本地存储文件：\(path)\n请先安装并打开 QClaw，完成一次登录/授权。"
        case .invalidJSON:
            return "app-store.json 格式无效"
        case .keychainNotFound:
            return "未在 Keychain 中找到 QClaw Safe Storage。\n请确保 QClaw 已完成登录。"
        case .apiKeyNotFound:
            return "未找到 apiKey。\n请先在 QClaw 中完成登录并初始化默认 provider。"
        case .userInfoNotFound:
            return "未找到用户信息。\n请先在 QClaw 中完成登录。"
        case .noModelList:
            return "模型列表响应中没有 model_status_list"
        case .noBalanceData:
            return "无法获取积分余额数据"
        case .noFlowData:
            return "无法获取积分流水数据"
        case .noUsageData:
            return "无法获取用量数据"
        }
    }
}

// MARK: - QClawService

class QClawService {
    static let shared = QClawService()
    private init() {}

    // MARK: File & Keychain

    func getAppStorePath() -> String {
        return ProcessInfo.processInfo.environment["QCLAW_APP_STORE_PATH"] ?? QCLAW_APP_STORE_PATH
    }

    func readAppStore() throws -> [String: Any] {
        let path = getAppStorePath()
        guard FileManager.default.fileExists(atPath: path) else {
            throw ServiceError.appStoreNotFound(path)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.invalidJSON
        }
        return json
    }

    func getKeychainPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: QCLAW_KEYCHAIN_SERVICE,
            kSecAttrAccount as String: QCLAW_KEYCHAIN_ACCOUNT,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ServiceError.keychainNotFound
        }
        return password
    }

    // MARK: Decryption

    func decryptStoredValue(_ storedValue: Any?, password: String? = nil) throws -> String {
        if let str = storedValue as? String {
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let dict = storedValue as? [String: Any] else {
            return ""
        }

        if let value = dict["value"] as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let cipherText = dict["cipherText"] as? String {
            let pass = try password ?? getKeychainPassword()
            return try decryptChromiumV10(cipherText: cipherText, password: pass)
        }

        return ""
    }

    // MARK: API Key

    func readApiKey() throws -> String {
        let store = try readAppStore()
        guard let storedValue = store[QCLAW_API_KEY_STORE_KEY] else {
            throw ServiceError.apiKeyNotFound
        }
        let apiKey = try decryptStoredValue(storedValue)
        guard !apiKey.isEmpty else {
            throw ServiceError.apiKeyNotFound
        }
        return apiKey
    }

    // MARK: Auth Session

    func readAuthSession() throws -> QClawAuthSession {
        let store = try readAppStore()
        let password = try getKeychainPassword()

        guard let rawUserInfo = try? decryptStoredValue(store[QCLAW_USER_INFO_STORE_KEY], password: password),
              !rawUserInfo.isEmpty,
              let userInfoData = rawUserInfo.data(using: .utf8),
              let userInfoDict = try? JSONSerialization.jsonObject(with: userInfoData) as? [String: Any] else {
            throw ServiceError.userInfoNotFound
        }

        let userInfo = UserInfo(
            loginKey: userInfoDict["loginKey"] as? String,
            guid: userInfoDict["guid"] as? String,
            userId: userInfoDict["userId"] as? String
        )

        let jwtToken = (try? decryptStoredValue(store[QCLAW_JWT_TOKEN_STORE_KEY], password: password)) ?? ""

        return QClawAuthSession(userInfo: userInfo, jwtToken: jwtToken)
    }

    // MARK: Models

    func fetchModels() async throws -> [ModelInfo] {
        let session = try readAuthSession()
        let result = try await qclawCommonFetch(endpoint: "data/4320/forward", payload: [:], session: session)
        try assertQClawSuccess(result, endpoint: "data/4320/forward")

        guard let data = extractRespData(result.payload),
              let modelRows = data["model_status_list"] as? [[String: Any]] else {
            throw ServiceError.noModelList
        }

        let modelIds = modelRows.compactMap { $0["id"] as? String }
        var rateRows: [[String: Any]] = []

        if !modelIds.isEmpty {
            let ratesResult = try await qclawCommonFetch(
                endpoint: "data/4327/forward",
                payload: ["model_ids": modelIds],
                session: session
            )
            if ratesResult.ok {
                let common = extractRespCommon(ratesResult.payload)
                if common == nil || (common?["code"] as? Int) == 0 {
                    if let ratesData = extractRespData(ratesResult.payload),
                       let rows = ratesData["rates"] as? [[String: Any]] {
                        rateRows = rows
                    }
                }
            }
        }

        return normalizeModelRows(modelRows: modelRows, rateRows: rateRows)
    }

    private func normalizeModelRows(modelRows: [[String: Any]], rateRows: [[String: Any]]) -> [ModelInfo] {
        let rates = Dictionary(uniqueKeysWithValues: rateRows.compactMap { rate -> (String, String)? in
            guard let id = rate["model_id"] as? String,
                  let multiplier = rate["rate_multiplier"] as? String else { return nil }
            return (id, multiplier)
        })

        return modelRows.map { model in
            let id = (model["id"] as? String) == "default" ? "modelroute" : (model["id"] as? String ?? "")
            let statusLevel = model["status_level"] as? Int ?? 0
            let status: String = {
                switch statusLevel {
                case 1: return "busy"
                case 2: return "full"
                case 3: return "unavailable"
                default: return "available"
                }
            }()
            return ModelInfo(
                id: id,
                name: model["name"] as? String ?? "",
                status: status,
                rate: rates[id],
                capabilities: model["capabilities"] as? [String] ?? []
            )
        }
    }

    // MARK: Balance

    func fetchBalance() async throws -> BalanceInfo {
        let session = try readAuthSession()
        let result = try await qclawCommonFetch(endpoint: "data/4110/forward", payload: [:], session: session)
        try assertQClawSuccess(result, endpoint: "data/4110/forward")

        guard let data = extractRespData(result.payload) else {
            throw ServiceError.noBalanceData
        }
        return normalizeBalance(data)
    }

    private func normalizeBalance(_ account: [String: Any]) -> BalanceInfo {
        let detail = account["balance_detail"] as? [String: Any] ?? [:]
        let dailyFree = (detail["daily_free"] as? NSNumber)?.doubleValue ?? 0
        let activityQ = (detail["activity_q"] as? NSNumber)?.doubleValue ?? 0

        return BalanceInfo(
            balance: (account["balance"] as? NSNumber)?.doubleValue ?? 0,
            activityPoints: dailyFree + activityQ,
            subscriptionPoints: (detail["subscription_q"] as? NSNumber)?.doubleValue ?? 0,
            packagePoints: (detail["package_q"] as? NSNumber)?.doubleValue ?? 0,
            totalDailyFreeGranted: (account["total_daily_free_granted"] as? NSNumber)?.doubleValue ?? 0,
            updatedAt: account["updated_at"] as? String ?? "",
            items: detail["items"] as? [[String: Any]] ?? []
        )
    }

    func fetchPointFlows(page: Int = 1, pageSize: Int = 20) async throws -> (PointFlowSummary, [[String: Any]]?) {
        let session = try readAuthSession()
        let payload: [String: Any] = [
            "offset": (page - 1) * pageSize,
            "limit": pageSize,
            "page": page,
            "page_size": pageSize,
        ]
        let result = try await qclawCommonFetch(endpoint: "data/4222/forward", payload: payload, session: session)
        try assertQClawSuccess(result, endpoint: "data/4222/forward")

        guard let data = extractRespData(result.payload) else {
            throw ServiceError.noFlowData
        }
        return (summarizePointFlows(data), data["flows"] as? [[String: Any]])
    }

    private func summarizePointFlows(_ details: [String: Any]) -> PointFlowSummary {
        let flows = details["flows"] as? [[String: Any]] ?? []
        let totalFlows = (details["total"] as? NSNumber)?.intValue ?? flows.count
        let page = (details["page"] as? NSNumber)?.intValue ?? 1
        let pageSize = (details["page_size"] as? NSNumber)?.intValue ?? flows.count

        var consumed = 0.0
        var gained = 0.0
        for flow in flows {
            let amount = (flow["amount"] as? NSNumber)?.doubleValue ?? 0
            if let direction = flow["direction"] as? Int {
                if direction == 2 { consumed += amount }
                else if direction == 1 { gained += amount }
            }
        }

        return PointFlowSummary(
            totalFlows: totalFlows,
            page: page,
            pageSize: pageSize,
            flowCountInPage: flows.count,
            consumedInPage: consumed,
            gainedInPage: gained
        )
    }

    // MARK: Token Usage

    func fetchDailyTokenUsage() async throws -> [String: Any] {
        let session = try readAuthSession()
        let result = try await qclawCommonFetch(endpoint: "data/4075/forward", payload: [:], session: session)
        try assertQClawSuccess(result, endpoint: "data/4075/forward")
        return extractRespData(result.payload) ?? [:]
    }

    func fetchUsageDetails(date: String, page: Int = 1, pageSize: Int = 20) async throws -> UsageSummary {
        let session = try readAuthSession()
        let payload: [String: Any] = [
            "start_date": date,
            "end_date": date,
            "offset": (page - 1) * pageSize,
            "limit": pageSize,
            "page": page,
            "page_size": pageSize,
        ]
        let result = try await qclawCommonFetch(endpoint: "data/4172/forward", payload: payload, session: session)
        try assertQClawSuccess(result, endpoint: "data/4172/forward")

        guard let data = extractRespData(result.payload) else {
            throw ServiceError.noUsageData
        }
        return summarizeUsageDetails(data)
    }

    private func summarizeUsageDetails(_ details: [String: Any]) -> UsageSummary {
        let records = details["records"] as? [[String: Any]] ?? []
        let totalRecords = (details["total"] as? NSNumber)?.intValue ?? records.count

        var promptTokens = 0
        var completionTokens = 0
        var totalTokens = 0
        var cost = 0.0

        for record in records {
            promptTokens += (record["prompt_tokens"] as? NSNumber)?.intValue ?? 0
            completionTokens += (record["completion_tokens"] as? NSNumber)?.intValue ?? 0
            totalTokens += (record["total_tokens"] as? NSNumber)?.intValue ?? 0
            cost += (record["cost"] as? NSNumber)?.doubleValue ?? 0
        }

        return UsageSummary(
            totalRecords: totalRecords,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            cost: cost
        )
    }
}