import SwiftUI

@main
struct ChronicleWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchHome() }
    }
}

private struct WatchHome: View {
    private let defaults: UserDefaults
    private let key = "cronicle.ledger"
    @State private var ledger: WatchLedger?
    @State private var path: [UUID] = []
    @State private var title = ""
    @State private var error = false
    @State private var showingBrief = false

    init() {
        var defaults = UserDefaults.standard
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["CRONICLE_TEST_LEDGER"],
           let testDefaults = UserDefaults(suiteName: "cronicle-test-" + suite) {
            defaults = testDefaults
            if defaults.data(forKey: key) == nil {
                var fixture = WatchLedger()
                fixture.add("Collect probes")
                defaults.set(try? JSONEncoder().encode(fixture), forKey: key)
            }
        }
        #endif
        self.defaults = defaults
        let stored = defaults.data(forKey: key)
        _ledger = State(initialValue: stored.map { try? JSONDecoder().decode(WatchLedger.self, from: $0) } ?? WatchLedger())
    }

    var body: some View {
        NavigationStack(path: $path) {
            if let ledger {
                List {
                    if let active = ledger.active,
                       let task = ledger.tasks.first(where: { $0.id == active.id }) {
                        Section("Now") {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(task.title).font(.headline)
                                Text(active.startedAt, style: .timer)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Button("Stop timer", systemImage: "stop.fill") {
                                update { $0.stop(at: .now) }
                            }
                            .accessibilityIdentifier("stop-timer")
                            Button("Mark complete", systemImage: "checkmark.circle") {
                                update { $0.complete(task.id, at: .now) }
                            }
                        }
                    }
                    Section("Tasks") {
                        TextField(
                            "New task",
                            text: $title,
                            prompt: Text("New task").foregroundColor(.primary)
                        )
                            .submitLabel(.done)
                            .onSubmit(addTask)
                        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Add task", systemImage: "plus", action: addTask)
                        }
                        ForEach(ledger.tasks.filter { !$0.done && $0.id != ledger.active?.id }) { task in
                            NavigationLink(value: task.id) {
                                Text(task.title)
                            }
                            .accessibilityIdentifier("open-task-" + task.title)
                        }
                    }
                    if ledger.tasks.contains(where: \.done) {
                        Section("Completed") {
                            ForEach(ledger.tasks.filter(\.done)) { task in
                                Text(task.title)
                                    .accessibilityIdentifier("completed-task-" + task.title)
                            }
                        }
                    }
                }
                .navigationTitle("Cronicle")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingBrief = true
                        } label: {
                            Label("Focus Brief", systemImage: "list.bullet.rectangle")
                                .labelStyle(.iconOnly)
                        }
                        .accessibilityIdentifier("focus-brief")
                    }
                }
                .sheet(isPresented: $showingBrief) {
                    FocusBriefView(brief: ledger.focusBrief) { id in
                        if update({ $0.start(id, at: .now) }) { showingBrief = false }
                    }
                }
                .navigationDestination(for: UUID.self) { id in taskDetail(id) }
            } else {
                Text("Saved tasks couldn’t be read.")
                    .navigationTitle("Cronicle")
            }
        }
        .alert("Couldn’t save changes", isPresented: $error) {
            Button("OK", role: .cancel) {}
        }
    }

    private func taskDetail(_ id: UUID) -> some View {
        List {
            if let task = ledger?.tasks.first(where: { $0.id == id }) {
                Text(task.title).font(.headline)
                if task.seconds > 0 {
                    Text(Duration.seconds(task.seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated)))
                        .foregroundStyle(.secondary)
                }
                if !task.done {
                    Button(ledger?.active == nil ? "Start timer" : "Switch timer", systemImage: "play.fill") {
                        if update({ $0.start(id, at: .now) }) { path.removeAll() }
                    }
                    Button("Mark complete", systemImage: "checkmark.circle") {
                        if update({ $0.complete(id, at: .now) }) { path.removeAll() }
                    }
                }
            }
        }
        .navigationTitle("Task")
    }

    private func addTask() {
        if update({ $0.add(title) }) { title = "" }
    }

    @discardableResult
    private func update<T>(_ change: (inout WatchLedger) -> T) -> Bool {
        guard var state = ledger else { return false }
        _ = change(&state)
        do {
            defaults.set(try JSONEncoder().encode(state), forKey: key)
            ledger = state
            return true
        } catch {
            self.error = true
            return false
        }
    }
}
