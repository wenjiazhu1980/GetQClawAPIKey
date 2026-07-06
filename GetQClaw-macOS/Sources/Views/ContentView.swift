import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                Text("API Key").tag(0)
                Text("模型").tag(1)
                Text("余额").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            switch selectedTab {
            case 0: ApiKeyView()
            case 1: ModelsView()
            case 2: BalanceView()
            default: EmptyView()
            }
        }
        .padding(.bottom, 12)
    }
}