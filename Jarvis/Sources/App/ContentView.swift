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
                                .rotationEffect(.degrees(appState.isNetworkActive ? 15 : 0))
                                .animation(
                                    .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                    value: appState.isNetworkActive
                                )
                            Text("Network Active")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityElement(children: .combine)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
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
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// Dummy placeholder views and classes for preview and completeness
struct ChatView: View {
    var body: some View {
        Text("Chat goes here")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.title)
            .padding()
    }
}

// Dummy app state and network guard for preview
class AppState: ObservableObject {
    @Published var isNetworkActive: Bool = true
}

class NetworkGuard: ObservableObject {}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(NetworkGuard())
    }
}
