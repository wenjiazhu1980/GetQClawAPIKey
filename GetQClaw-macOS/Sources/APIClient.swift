import Foundation

// MARK: - Constants

let JPRX_GATEWAY = "https://jprx.m.qq.com/"

// MARK: - API Client

struct APIResponse {
    let ok: Bool
    let status: Int
    let payload: [String: Any]?
}

enum APIError: LocalizedError {
    case invalidURL
    case httpError(String, Int)
    case businessError(String, Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .httpError(let endpoint, let status): return "\(endpoint) HTTP \(status)"
        case .businessError(let endpoint, let code, let message):
            return "\(endpoint) code=\(code) \(message)"
        }
    }
}

// MARK: - Helpers

func buildCommonHeaders(session: QClawAuthSession) -> [String: String] {
    var headers: [String: String] = [
        "Content-Type": "application/json",
        "X-Version": "1",
        "X-Token": session.userInfo.loginKey ?? "",
        "X-Guid": session.userInfo.guid ?? "1",
        "X-Account": session.userInfo.userId ?? "1",
        "X-Session": "",
        "X-Qclaw-DeviceToken": session.userInfo.guid ?? "",
    ]
    if !session.jwtToken.isEmpty {
        headers["X-OpenClaw-Token"] = session.jwtToken
    }
    return headers
}

func qclawCommonFetch(endpoint: String, payload: [String: Any] = [:],
                      session: QClawAuthSession) async throws -> APIResponse {
    let urlString = JPRX_GATEWAY + endpoint
    guard let url = URL(string: urlString) else {
        throw APIError.invalidURL
    }

    var body = payload
    body["web_version"] = "1.4.0"
    body["web_env"] = "release"

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = buildCommonHeaders(session: session)
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = response as! HTTPURLResponse
    let parsed = data.isEmpty ? nil : try JSONSerialization.jsonObject(with: data) as? [String: Any]

    return APIResponse(
        ok: (200...299).contains(httpResponse.statusCode),
        status: httpResponse.statusCode,
        payload: parsed
    )
}

func extractRespCommon(_ payload: [String: Any]?) -> [String: Any]? {
    guard let payload = payload else { return nil }
    if let data = payload["data"] as? [String: Any],
       let resp = data["resp"] as? [String: Any],
       let common = resp["common"] as? [String: Any] { return common }
    if let data = payload["data"] as? [String: Any],
       let common = data["common"] as? [String: Any] { return common }
    if let resp = payload["resp"] as? [String: Any],
       let common = resp["common"] as? [String: Any] { return common }
    return payload["common"] as? [String: Any]
}

func extractRespData(_ payload: [String: Any]?) -> [String: Any]? {
    guard let payload = payload else { return nil }
    if let data = payload["data"] as? [String: Any],
       let resp = data["resp"] as? [String: Any],
       let inner = resp["data"] as? [String: Any] { return inner }
    if let data = payload["data"] as? [String: Any],
       let inner = data["data"] as? [String: Any] { return inner }
    if let resp = payload["resp"] as? [String: Any],
       let inner = resp["data"] as? [String: Any] { return inner }
    return payload["data"] as? [String: Any]
}

func assertQClawSuccess(_ result: APIResponse, endpoint: String) throws {
    if !result.ok {
        throw APIError.httpError(endpoint, result.status)
    }
    if let common = extractRespCommon(result.payload),
       let code = common["code"] as? Int, code != 0 {
        let message = common["message"] as? String ?? "业务请求失败"
        throw APIError.businessError(endpoint, code, message)
    }
}