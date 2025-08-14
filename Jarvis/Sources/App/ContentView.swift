import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var networkGuard: NetworkGuard
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(
                    #if os(iOS)
                    UIColor.systemBackground
                    #elseif os(macOS)
                    NSColor.windowBackgroundColor
                    #else
                    .white
                    #endif
                )
                .ignoresSafeArea()

                ChatView()
                    .padding(.top, appState.currentMode != .offline ? 40 : 0)

                if appState.currentMode != .offline {
                    HStack {
                        Image(systemName: "wifi")
                        Text("Network Active")
                    }
                    .padding()
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
