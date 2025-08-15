import SwiftUI
import MLCSwift
import AVFoundation

// MARK: - ConversationStore Extensions
extension ConversationStore {
    // Chat-specific methods
    func addUserMessage(_ text: String) {
        let message = Message(
            id: UUID(),
            content: text,
            isUser: true,
            timestamp: Date()
        )
        addMessage(message)
    }

    func addAssistantMessage(_ text: String) {
        let message = Message(
            id: UUID(),
            content: text,
            isUser: false,
            timestamp: Date()
        )
        addMessage(message)
    }

    func addStreamingResponse(_ streamingText: String) -> Message {
        return Message(
            id: UUID(),
            content: streamingText,
            isUser: false,
            timestamp: Date()
        )
    }

    // Chat UI helpers
    var hasMessages: Bool {
        return !messages.isEmpty
    }

    var canSendMessage: Bool {
        return !messages.isEmpty || true // Always allow first message
    }
}

// MARK: - Message Extensions for Chat
extension Message {
    var displayContent: String {
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

struct ChatView: View {
    @EnvironmentObject private var modelRuntime: ModelRuntime
    @EnvironmentObject private var appState: AppState
    @StateObject private var conversationStore = ConversationStore.shared
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var imageAnalyzer = ImageAnalyzer()

    @State private var messageText = ""
    @State private var isRecording = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isGenerating = false
    @State private var streamingText = ""
    @State private var currentGenerationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Message list with auto-scroll
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversationStore.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                        if isGenerating && !streamingText.isEmpty {
                            MessageRow(message: Message(
                                id: UUID(),
                                content: streamingText,
                                isUser: false,
                                timestamp: Date()
                            ))
                            .opacity(0.8)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: conversationStore.messages.count) { _ in
                    if let lastMessage = conversationStore.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area with voice/image/text controls
            VStack(spacing: 12) {
                HStack {
                    Button {
                        toggleRecording()
                    } label: {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .foregroundColor(isRecording ? .red : .blue)
                            .font(.title2)
                    }
                    .disabled(isGenerating)

                    Spacer()

                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    .disabled(isGenerating)

                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    .disabled(isGenerating)
                }
                .padding(.horizontal)

                HStack {
                    TextField("Ask Jarvis...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isGenerating)

                    Button {
                        if isGenerating {
                            stopGeneration()
                        } else {
                            sendMessage()
                        }
                    } label: {
                        Image(systemName: isGenerating ? "stop.circle" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty && !isGenerating ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty && !isGenerating)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color(.systemGray6))
        }
        .onAppear {
            setupAudioSession()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { image in
                processImage(image)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraCapture { image in
                processImage(image)
            }
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        conversationStore.addUserMessage(messageText)
        let prompt = messageText
        messageText = ""

        generateResponse(for: prompt)
    }

    private func generateResponse(for prompt: String) {
        isGenerating = true
        streamingText = ""

        // Cancel any existing task
        currentGenerationTask?.cancel()

        // Create new task and store reference
        currentGenerationTask = Task {
            do {
                let enhancedPrompt = await enhancePromptIfNeeded(prompt)

                try await modelRuntime.generateTextStream(
                    prompt: enhancedPrompt,
                    maxTokens: 512,
                    temperature: 0.7
                ) { token in
                    // Check if task was cancelled
                    guard !Task.isCancelled else { return }

                    DispatchQueue.main.async {
                        streamingText += token
                    }
                }

                await MainActor.run {
                    // Only complete if not cancelled
                    guard !Task.isCancelled else { return }

                    conversationStore.addAssistantMessage(streamingText)
                    streamingText = ""
                    isGenerating = false
                    currentGenerationTask = nil
                }

            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }

                    conversationStore.addAssistantMessage("Sorry, I encountered an error: \(error.localizedDescription)")
                    streamingText = ""
                    isGenerating = false
                    currentGenerationTask = nil
                }
            }
        }
    }

    private func stopGeneration() {
        // Cancel the current generation task
        currentGenerationTask?.cancel()
        currentGenerationTask = nil

        // Save any partial streaming text
        if !streamingText.isEmpty {
            let partialMessage = Message(
                id: UUID(),
                content: streamingText + " [Response stopped by user]",
                isUser: false,
                timestamp: Date()
            )
            conversationStore.addMessage(partialMessage)
        }

        // Reset state
        streamingText = ""
        isGenerating = false
    }

    private func enhancePromptIfNeeded(_ prompt: String) async -> String {
        guard appState.currentMode != .offline else { return prompt }

        switch appState.currentMode {
        case .quickSearch:
            if let searchResults = await QuickSearch.shared.search(query: prompt) {
                return "\(prompt)\n\nContext from search:\n\(searchResults)"
            }
        case .deepResearch:
            if let researchResults = await DeepResearch.shared.research(query: prompt) {
                return "\(prompt)\n\nDetailed research context:\n\(researchResults)"
            }
        case .offline, .voiceControl:
            break
        }

        return prompt
    }

    private func toggleRecording() {
        if isRecording {
            audioEngine.stopRecording()
        } else {
            audioEngine.startRecording { transcription in
                messageText = transcription
            }
        }
        isRecording.toggle()
    }

    private func processImage(_ image: UIImage) {
        Task {
            let ocrText = await imageAnalyzer.extractText(from: image)
            let classification = await imageAnalyzer.classifyImage(image)

            let imagePrompt = "I've captured an image. OCR text: \(ocrText). Classification: \(classification). Please analyze this image."

            await MainActor.run {
                messageText = imagePrompt
            }
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
}
