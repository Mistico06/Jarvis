import SwiftUI

struct VoiceControlView: View {
    @StateObject private var audioEngine = AudioEngine()
    @State private var isRecording = false
    @State private var transcript = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(transcript.isEmpty ? "Say something..." : transcript)
                .padding()
                .multilineTextAlignment(.center)

            Button(isRecording ? "Stop Recording" : "Start Recording") {
                if isRecording {
                    audioEngine.stopRecording()
                    isRecording = false
                } else {
                    audioEngine.startRecording { text in
                        DispatchQueue.main.async {
                            transcript = text
                        }
                    }
                    isRecording = true
                }
            }
            .padding()
            .background(isRecording ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            Button("Speak") {
                audioEngine.speak(text: "Hello, Jarvis!")
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)

            Button("Stop Speaking") {
                audioEngine.stopSpeaking()
            }
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .navigationTitle("Voice Control")
    }
}

struct VoiceControlView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceControlView()
    }
}
