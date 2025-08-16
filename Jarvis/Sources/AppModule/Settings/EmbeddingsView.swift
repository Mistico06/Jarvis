import SwiftUI

struct EmbeddingsView: View {
    @EnvironmentObject private var embeddingsManager: EmbeddingsManager
    @State private var showingRebuildAlert = false
    @State private var showingClearAlert = false

    var body: some View {
        NavigationView {
            List {
                // MARK: Statistics
                Section(header: Text("Statistics")) {
                    row("Total Embeddings", value: "\(embeddingsManager.totalEmbeddings)")
                    row("Storage Used", value: embeddingsManager.storageSize)
                    rowDate("Last Updated", date: embeddingsManager.lastUpdated, relative: true)
                    row("Vector Dimensions", value: "\(embeddingsManager.vectorDimensions)")
                }

                // MARK: Knowledge Sources
                Section(header: Text("Knowledge Sources")) {
                    ForEach(embeddingsManager.knowledgeSources, id: \.id) { source in
                        HStack {
                            Image(systemName: source.icon).foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(source.name)
                                    .font(.headline)
                                Text("\(source.embeddingCount) embeddings • \(source.lastUpdated, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if source.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions {
                            Button("Rebuild") {
                                embeddingsManager.rebuildSource(source)
                            }
                            .tint(.blue)

                            Button("Delete", role: .destructive) {
                                embeddingsManager.deleteSource(source)
                            }
                        }
                    }
                }

                // MARK: Actions
                Section(header: Text("Actions")) {
                    Button("Rebuild All Embeddings") {
                        showingRebuildAlert = true
                    }
                    .disabled(embeddingsManager.isRebuilding)

                    Button("Export Embeddings") {
                        embeddingsManager.exportEmbeddings()
                    }

                    Button("Import Embeddings") {
                        embeddingsManager.importEmbeddings()
                    }

                    Button("Clear All Embeddings") {
                        showingClearAlert = true
                    }
                    .foregroundColor(.red)
                }

                if embeddingsManager.isRebuilding {
                    Section(header: Text("Progress")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Rebuilding embeddings...")
                                Spacer()
                                Text("\(Int(embeddingsManager.rebuildProgress * 100))%")
                            }
                            ProgressView(value: embeddingsManager.rebuildProgress)
                        }
                    }
                }
            }
            .navigationTitle("Embeddings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                embeddingsManager.refreshData()
            }
            .alert("Rebuild All Embeddings", isPresented: $showingRebuildAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Rebuild", role: .destructive) {
                    embeddingsManager.rebuildAllEmbeddings()
                }
            } message: {
                Text("This will rebuild all embeddings from your knowledge sources. This process may take several minutes.")
            }
            .alert("Clear All Embeddings", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    embeddingsManager.clearAllEmbeddings()
                }
            } message: {
                Text("This will permanently delete all embeddings. You'll need to rebuild them to use knowledge search.")
            }
        }
    }

    // MARK: - Row helpers

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func rowDate(_ title: String, date: Date, relative: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if relative {
                Text(date, style: .relative)
                    .foregroundColor(.secondary)
            } else {
                Text(date.formatted())
                    .foregroundColor(.secondary)
            }
        }
    }
}
