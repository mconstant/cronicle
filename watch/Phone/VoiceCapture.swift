import AVFoundation
import Speech
import SwiftUI

@MainActor
final class VoiceCapture: ObservableObject {
    @Published private(set) var listening = false
    @Published var message: String?
    private let engine = AVAudioEngine()
    private var recognition: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var sessionID = UUID()

    func start(onTranscript: @escaping (String) -> Void) {
        stop()
        let id = sessionID
        Task {
            let permission = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard id == sessionID else { return }
            guard permission == .authorized, await AVAudioApplication.requestRecordPermission() else {
                if id == sessionID { message = "Voice access is unavailable. You can still type this task." }
                return
            }
            guard id == sessionID else { return }
            guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable,
                  recognizer.supportsOnDeviceRecognition else {
                message = "On-device speech is unavailable. You can still type this task."
                return
            }

            do {
                try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
                try AVAudioSession.sharedInstance().setActive(true)
                let audioRequest = SFSpeechAudioBufferRecognitionRequest()
                audioRequest.requiresOnDeviceRecognition = true
                audioRequest.shouldReportPartialResults = true
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else {
                    stop()
                    message = "No microphone is available. You can still type this task."
                    return
                }
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    audioRequest.append(buffer)
                }
                request = audioRequest
                engine.prepare()
                try engine.start()
                listening = true
                message = "Listening…"
                recognition = recognizer.recognitionTask(with: audioRequest) { result, error in
                    let transcript = result?.bestTranscription.formattedString
                    let finished = result?.isFinal == true
                    let failed = error != nil
                    Task { @MainActor [weak self] in
                        guard let self, self.sessionID == id else { return }
                        if let transcript { onTranscript(transcript) }
                        if finished || failed {
                            self.stop()
                            if failed && transcript == nil {
                                self.message = "Speech ended. You can edit or type your task."
                            }
                        }
                    }
                }
            } catch {
                stop()
                message = "Couldn’t start the microphone. You can still type this task."
            }
        }
    }

    func stop() {
        sessionID = UUID()
        if request != nil {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        recognition?.cancel()
        request = nil
        recognition = nil
        listening = false
        message = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
