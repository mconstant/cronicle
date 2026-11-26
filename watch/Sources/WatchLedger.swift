import Foundation

struct WatchTask: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    var done = false
    var seconds: TimeInterval = 0
}

struct WatchLedger: Codable, Equatable {
    struct Tracking: Codable, Equatable {
        let id: UUID
        let startedAt: Date
    }

    private(set) var tasks: [WatchTask] = []
    private(set) var active: Tracking?

    @discardableResult
    mutating func add(_ input: String) -> UUID? {
        let title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        if let match = tasks.first(where: { !$0.done && $0.title.caseInsensitiveCompare(title) == .orderedSame }) {
            return match.id
        }
        let item = WatchTask(id: UUID(), title: title)
        tasks.append(item)
        return item.id
    }

    mutating func start(_ id: UUID, at date: Date) {
        guard active?.id != id, tasks.contains(where: { $0.id == id && !$0.done }) else { return }
        stop(at: date)
        active = Tracking(id: id, startedAt: date)
    }

    mutating func stop(at date: Date) {
        guard let active else { return }
        if let index = tasks.firstIndex(where: { $0.id == active.id }) {
            tasks[index].seconds += max(0, date.timeIntervalSince(active.startedAt))
        }
        self.active = nil
    }

    mutating func complete(_ id: UUID, at date: Date) {
        if active?.id == id { stop(at: date) }
        if let index = tasks.firstIndex(where: { $0.id == id }) { tasks[index].done = true }
    }
}
