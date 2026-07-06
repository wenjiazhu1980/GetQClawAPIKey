import SwiftUI

struct BalanceView: View {
    @State private var balance: BalanceInfo?
    @State private var pointFlow: PointFlowSummary?
    @State private var dailyUsage: [String: Any]?
    @State private var usageSummary: UsageSummary?
    @State private var error: String?
    @State private var isLoading = true
    @State private var showTokens = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("加载余额数据...")
                    Spacer()
                }
                .padding(.top, 30)
            } else if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    Button("重试") { loadBalance() }
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let balance = balance {
                            SectionHeader("积分余额")
                            InfoRow("总积分", String(format: "%.4f", balance.balance))
                            InfoRow("活动积分", String(format: "%.4f", balance.activityPoints))
                            if balance.subscriptionPoints > 0 {
                                InfoRow("订阅积分", String(format: "%.4f", balance.subscriptionPoints))
                            }
                            if balance.packagePoints > 0 {
                                InfoRow("积分包", String(format: "%.4f", balance.packagePoints))
                            }
                            InfoRow("累计赠送", String(format: "%.0f", balance.totalDailyFreeGranted))
                            if !balance.updatedAt.isEmpty {
                                InfoRow("更新时间", balance.updatedAt)
                            }
                        }

                        if let flow = pointFlow {
                            Divider().padding(.vertical, 4)
                            SectionHeader("积分流水（第\(flow.page)页）")
                            InfoRow("总流水数", "\(flow.totalFlows)")
                            InfoRow("本页消耗", String(format: "%.4f", flow.consumedInPage))
                            InfoRow("本页收入", String(format: "%.4f", flow.gainedInPage))
                        }

                        if showTokens, let daily = dailyUsage {
                            Divider().padding(.vertical, 4)
                            SectionHeader("Token 用量")
                            let limit = (daily["daily_token_limit"] as? NSNumber)?.intValue ?? 0
                            let used = (daily["daily_token_used"] as? NSNumber)?.intValue ?? 0
                            InfoRow("每日限额", "\(limit)")
                            InfoRow("已使用", "\(used)")
                            InfoRow("剩余", limit > 0 ? "\(limit - used)" : "-")
                            if let rpm = daily["rpm_limit"] {
                                InfoRow("RPM 限制", "\(rpm)")
                            }

                            if let usage = usageSummary {
                                Divider().padding(.vertical, 4)
                                SectionHeader("今日用量明细")
                                InfoRow("记录数", "\(usage.totalRecords)")
                                InfoRow("总 Token", "\(usage.totalTokens)")
                                InfoRow("Prompt", "\(usage.promptTokens)")
                                InfoRow("Completion", "\(usage.completionTokens)")
                                InfoRow("费用", String(format: "%.4f", usage.cost))
                            }
                        }

                        HStack {
                            Toggle("Token 用量", isOn: $showTokens)
                                .font(.caption)
                            Spacer()
                            Button("刷新") { loadBalance() }
                                .font(.caption)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                }
            }
        }
        .task { loadBalance() }
        .onChange(of: showTokens) { _, newValue in
            if newValue && dailyUsage == nil {
                loadTokenUsage()
            }
        }
    }

    private func loadBalance() {
        isLoading = true
        error = nil
        balance = nil
        pointFlow = nil
        dailyUsage = nil
        usageSummary = nil
        Task {
            do {
                let bal = try await QClawService.shared.fetchBalance()
                let (flow, _) = try await QClawService.shared.fetchPointFlows()
                await MainActor.run {
                    balance = bal
                    pointFlow = flow
                    isLoading = false
                }
                if showTokens {
                    await loadTokenUsageAsync()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func loadTokenUsage() {
        Task { await loadTokenUsageAsync() }
    }

    private func loadTokenUsageAsync() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: Date())

        do {
            let daily = try await QClawService.shared.fetchDailyTokenUsage()
            let usage = try await QClawService.shared.fetchUsageDetails(date: date)
            await MainActor.run {
                dailyUsage = daily
                usageSummary = usage
            }
        } catch {
            await MainActor.run {
                dailyUsage = ["error": error.localizedDescription]
            }
        }
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }
}