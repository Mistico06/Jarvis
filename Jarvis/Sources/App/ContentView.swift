import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var networkGuard: NetworkGuard
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main chat interface
                ChatView()
                
                // Network activity indicator
                if appState.isNetworkActive {
                    VStack {
                        HStack {
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
                        Spacer()
                    }
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
