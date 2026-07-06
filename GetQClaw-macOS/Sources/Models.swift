import Foundation

// MARK: - Auth Session

struct QClawAuthSession {
    let userInfo: UserInfo
    let jwtToken: String
}

struct UserInfo {
    let loginKey: String?
    let guid: String?
    let userId: String?
}

// MARK: - Model Info

struct ModelInfo {
    let id: String
    let name: String
    let status: String
    let rate: String?
    let capabilities: [String]
}

// MARK: - Balance

struct BalanceInfo {
    let balance: Double
    let activityPoints: Double
    let subscriptionPoints: Double
    let packagePoints: Double
    let totalDailyFreeGranted: Double
    let updatedAt: String
    let items: [[String: Any]]
}

struct PointFlowSummary {
    let totalFlows: Int
    let page: Int
    let pageSize: Int
    let flowCountInPage: Int
    let consumedInPage: Double
    let gainedInPage: Double
}

// MARK: - Usage

struct UsageSummary {
    let totalRecords: Int
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let cost: Double
}