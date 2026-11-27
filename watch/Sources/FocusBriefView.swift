import AVFoundation
import SwiftUI

struct FocusBriefView: View {
    let brief: FocusBrief
    let startNext: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var speaker = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            List {
                Section("Now") {
                    Text(brief.running?.title ?? "No timer running")
                        .accessibilityIdentifier("brief-running")
                }
                Section("Next") {
                    if let next = brief.next {
                        Text(next.title)
                            .accessibilityIdentifier("brief-next")
                        Button(brief.running == nil ? "Start next" : "Switch timer",
                               systemImage: brief.running == nil ? "play.fill" : "arrow.left.arrow.right") {
                            startNext(next.id)
                        }
                        .accessibilityIdentifier("brief-start")
                    } else {
                        Text("No tasks queued")
                    }
                }
                Section {
                    Button("Read aloud", systemImage: "speaker.wave.2") {
                        speaker.stopSpeaking(at: .immediate)
                        speaker.speak(AVSpeechUtterance(string: brief.spoken))
                    }
                    .accessibilityIdentifier("brief-speak")
                    Text(brief.completed == 1 ? "1 task complete" : "\(brief.completed) tasks complete")
                }
            }
            .navigationTitle("Focus Brief")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { speaker.stopSpeaking(at: .immediate) }
    }
}
