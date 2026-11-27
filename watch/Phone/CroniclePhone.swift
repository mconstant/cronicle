import SwiftUI

@main
struct CroniclePhoneApp: App {
    var body: some Scene {
        WindowGroup { PhoneHome() }
    }
}

private struct PhoneHome: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = VoiceCapture()
    @State private var ledger: WatchLedger?
    @State private var capturing = false
    @State private var title = ""
    @State private var saveFailed = false
    private let defaults: UserDefaults
    private let key = "cronicle.ledger"

    init() {
        var storage = UserDefaults.standard
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["CRONICLE_TEST_LEDGER"],
           let isolated = UserDefaults(suiteName: "cronicle-phone-test-" + suite) {
            storage = isolated
        }
        #endif
        defaults = storage
        if let data = storage.data(forKey: key) {
            _ledger = State(initialValue: try? JSONDecoder().decode(WatchLedger.self, from: data))
        } else {
            _ledger = State(initialValue: WatchLedger())
        }
    }

    var body: some View {
        NavigationStack {
            if let ledger {
                List {
                    Section {
                        Button {
                            openCapture(byVoice: true)
                        } label: {
                            Label("Speak a task", systemImage: "waveform")
                                .font(.headline)
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("speak-task")
                    } footer: {
                        Text("Say what you want to do. Review it before saving.")
                    }

                    if let timer = ledger.active,
                       let task = ledger.tasks.first(where: { $0.id == timer.id }) {
                        Section("In progress") {
                            Text(task.title)
                                .font(.headline)
                                .accessibilityIdentifier("running-task")
                            Text(timer.startedAt, style: .timer)
                                .font(.title2.monospacedDigit())
                            Button("Stop timer", systemImage: "stop.circle") {
                                update { $0.stop(at: .now) }
                            }
                            Button("Mark complete", systemImage: "checkmark.circle") {
                                update { $0.complete(task.id, at: .now) }
                            }
                            .accessibilityIdentifier("complete-running")
                        }
                    }

                    Section("Up next") {
                        let ready = ledger.tasks.filter { !$0.done && $0.id != ledger.active?.id }
                        if ready.isEmpty {
                            Text("Your list is clear.").foregroundStyle(.secondary)
                        }
                        ForEach(ready) { task in
                            HStack {
                                Text(task.title)
                                Spacer()
                                Button {
                                    update { $0.start(task.id, at: .now) }
                                } label: {
                                    Image(systemName: "play.circle")
                                        .font(.title2)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(ledger.active == nil ? "Start \(task.title)" : "Switch to \(task.title)")
                                .accessibilityIdentifier("start-" + task.title)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Complete", systemImage: "checkmark") {
                                    update { $0.complete(task.id, at: .now) }
                                }
                                .tint(.green)
                            }
                        }
                    }

                    if ledger.tasks.contains(where: \.done) {
                        Section("Completed") {
                            ForEach(ledger.tasks.filter(\.done)) { task in
                                Label(task.title, systemImage: "checkmark.circle")
                                    .accessibilityIdentifier("completed-" + task.title)
                            }
                        }
                    }
                }
                .navigationTitle("Today")
                .toolbar {
                    Button("Type a task", systemImage: "plus") {
                        openCapture(byVoice: false)
                    }
                    .accessibilityIdentifier("capture-task")
                }
            } else {
                ContentUnavailableView("Saved tasks couldn’t be read", systemImage: "exclamationmark.circle")
            }
        }
        .sheet(isPresented: $capturing, onDismiss: { speech.stop() }) {
            NavigationStack {
                Form {
                    Section("Task") {
                        TextField("What do you want to do?", text: Binding(
                            get: { title },
                            set: {
                                speech.stop()
                                title = $0
                            }
                        ))
                            .accessibilityIdentifier("task-title")
                        Button(speech.listening ? "Stop listening" : "Speak", systemImage: speech.listening ? "stop.circle" : "mic") {
                            if speech.listening { speech.stop() }
                            else { startListening() }
                        }
                        if let message = speech.message {
                            Text(message).foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("New task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: closeCapture)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if update({ $0.add(title) }) { closeCapture() }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("save-task")
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { speech.stop() }
        }
        .alert("Couldn’t save changes", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func openCapture(byVoice: Bool) {
        title = ""
        speech.message = nil
        capturing = true
        if byVoice { startListening() }
    }

    private func closeCapture() {
        speech.stop()
        capturing = false
    }

    private func startListening() {
        speech.start { transcript in
            if capturing { title = transcript }
        }
    }

    @discardableResult
    private func update<T>(_ change: (inout WatchLedger) -> T) -> Bool {
        guard var updated = ledger else { return false }
        _ = change(&updated)
        do {
            defaults.set(try JSONEncoder().encode(updated), forKey: key)
            ledger = updated
            return true
        } catch {
            saveFailed = true
            return false
        }
    }
}
