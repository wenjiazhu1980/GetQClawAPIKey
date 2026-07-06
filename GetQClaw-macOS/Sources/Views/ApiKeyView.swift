import SwiftUI

struct ApiKeyView: View {
    @State private var apiKey: String?
    @State private var error: String?
    @State private var isLoading = true
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("读取中...")
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
                    Button("重试") { loadApiKey() }
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else if let key = apiKey {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("API Key")
                            .font(.headline)

                        HStack(spacing: 6) {
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(3)
                                .truncationMode(.middle)
                                .padding(8)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(key, forType: .string)
                                showCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showCopied = false
                                }
                            } label: {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("复制到剪贴板")
                        }

                        Text("curl 示例")
                            .font(.headline)
                            .padding(.top, 8)

                        Text("""
                        curl --location --request POST \\
                          'https://mmgrcalltoken.3g.qq.com/aizone/v1/chat/completions' \\
                          -H 'Authorization: Bearer \(key)' \\
                          -H 'Content-Type: application/json' \\
                          -d '{
                            "model": "modelroute",
                            "messages": [
                              { "role": "system", "content": "hi" },
                              { "role": "user", "content": "hi" }
                            ]
                          }'
                        """)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                }
            }

            Spacer()
        }
        .task { loadApiKey() }
    }

    private func loadApiKey() {
        isLoading = true
        error = nil
        apiKey = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let key = try QClawService.shared.readApiKey()
                DispatchQueue.main.async {
                    apiKey = key
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}