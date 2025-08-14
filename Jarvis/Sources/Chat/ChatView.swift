import SwiftUI
import AVFoundation

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
                            // Optionally implement stop generation logic
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
        
        let userMessage = Message(
            id: UUID(),
            content: messageText,
            isUser: true,
            timestamp: Date()
        )
        
        conversationStore.addMessage(userMessage)
        let prompt = messageText
        messageText = ""
        
        generateResponse(for: prompt)
    }
    
    private func generateResponse(for prompt: String) {
        isGenerating = true
        streamingText = ""
        
        Task {
            do {
                let enhancedPrompt = await enhancePromptIfNeeded(prompt)
                
                try await modelRuntime.generateTextStream(
                    prompt: enhancedPrompt,
                    maxTokens: modelRuntime.currentModel.maxTokens,
                    temperature: 0.7
                ) { token in
                    DispatchQueue.main.async {
                        streamingText += token
                    }
                }
                
                let responseMessage = Message(
                    id: UUID(),
                    content: streamingText,
                    isUser: false,
                    timestamp: Date()
                )
                
                await MainActor.run {
                    conversationStore.addMessage(responseMessage)
                    streamingText = ""
                    isGenerating = false
                }
                
            } catch {
                await MainActor.run {
                    let errorMessage = Message(
                        id: UUID(),
                        content: "Sorry, I encountered an error: \(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date()
                    )
                    conversationStore.addMessage(errorMessage)
                    streamingText = ""
                    isGenerating = false
                }
            }
        }
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
        case .offline:
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
