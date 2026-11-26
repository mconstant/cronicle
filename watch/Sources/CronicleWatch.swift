import SwiftUI

@main
struct ChronicleWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchHome() }
    }
}

private struct WatchHome: View {
    @AppStorage private var storage: Data
    @State private var title = ""
    @State private var error = false

    init() {
        let key = "cronicle.ledger"
        var defaults = UserDefaults.standard
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--test-ledger"),
           arguments.indices.contains(index + 1),
           let testDefaults = UserDefaults(suiteName: "cronicle-test-" + arguments[index + 1]) {
            defaults = testDefaults
            if defaults.data(forKey: key) == nil {
                var fixture = WatchLedger()
                fixture.add("Collect probes")
                defaults.set(try? JSONEncoder().encode(fixture), forKey: key)
            }
        }
        #endif
        _storage = AppStorage(wrappedValue: Data(), key, store: defaults)
    }

    private var ledger: WatchLedger? {
        if storage.isEmpty { return WatchLedger() }
        return try? JSONDecoder().decode(WatchLedger.self, from: storage)
    }

    var body: some View {
        NavigationStack {
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
                                    .accessibilityLabel("Elapsed time")
                            }
                            Button("Stop timer", systemImage: "stop.fill") {
                                update { $0.stop(at: .now) }
                            }
                            Button("Mark complete", systemImage: "checkmark.circle") {
                                update { $0.complete(task.id, at: .now) }
                            }
                        }
                    }
                    Section("Tasks") {
                        TextField("New task", text: $title)
                            .submitLabel(.done)
                            .onSubmit(addTask)
                        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Add task", systemImage: "plus", action: addTask)
                        }
                        ForEach(ledger.tasks.filter { !$0.done && $0.id != ledger.active?.id }) { task in
                            NavigationLink {
                                taskDetail(task.id)
                            } label: {
                                Text(task.title)
                            }
                        }
                    }
                    if ledger.tasks.contains(where: \.done) {
                        Section("Completed") {
                            ForEach(ledger.tasks.filter(\.done)) { task in
                                Text(task.title)
                            }
                        }
                    }
                }
                .navigationTitle("Cronicle")
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
                if task.done {
                    Label("Completed", systemImage: "checkmark.circle")
                } else if ledger?.active?.id == id {
                    Button("Stop timer", systemImage: "stop.fill") {
                        update { $0.stop(at: .now) }
                    }
                } else {
                    Button(ledger?.active == nil ? "Start timer" : "Switch timer", systemImage: "play.fill") {
                        update { $0.start(id, at: .now) }
                    }
                }
                if !task.done {
                    Button("Mark complete", systemImage: "checkmark.circle") {
                        update { $0.complete(id, at: .now) }
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
            storage = try JSONEncoder().encode(state)
            return true
        } catch {
            self.error = true
            return false
        }
    }
}
