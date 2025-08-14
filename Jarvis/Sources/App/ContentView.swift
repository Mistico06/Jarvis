import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var networkGuard: NetworkGuard
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // ✅ Simplified since you only target iOS
                Color(.systemBackground)
                    .ignoresSafeArea()

                // Main chat interface
                ChatView()
                    .padding(.top, appState.currentMode != .offline ? 40 : 0)

                // Network indicator
                if appState.currentMode != .offline {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .foregroundColor(.orange)
                        Text("Network Active")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Jarvis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}
