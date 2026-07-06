import SwiftUI

struct ModelsView: View {
    @State private var models: [ModelInfo]?
    @State private var error: String?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("加载模型列表...")
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
                    Button("重试") { loadModels() }
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else if let models = models {
                HStack(spacing: 4) {
                    Text("模型 ID / 名称")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("状态").frame(width: 65, alignment: .leading)
                    Text("倍率").frame(width: 40, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(models.indices, id: \.self) { index in
                            ModelRowView(model: models[index])
                            if index < models.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("刷新") { loadModels() }
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
        }
        .task { loadModels() }
    }

    private func loadModels() {
        isLoading = true
        error = nil
        models = nil
        Task {
            do {
                let result = try await QClawService.shared.fetchModels()
                await MainActor.run {
                    models = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct ModelRowView: View {
    let model: ModelInfo

    var statusColor: Color {
        switch model.status {
        case "available": return .green
        case "busy": return .orange
        case "full": return .yellow
        case "unavailable": return .red
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.id)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                Text(model.name)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(model.status)
                    .font(.caption)
            }
            .frame(width: 65, alignment: .leading)

            Text(model.rate ?? "-")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}