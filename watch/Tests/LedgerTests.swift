import Foundation

@main
struct LedgerTests {
    static func main() throws {
        let start = Date(timeIntervalSince1970: 100)
        var ledger = WatchLedger()
        precondition(ledger.add("  ") == nil)
        let first = ledger.add(" Collect probes ")!
        let second = ledger.add("Check oven")!
        precondition(ledger.add("collect probes") == first)
        precondition(ledger.tasks.count == 2)
        precondition(ledger.focusBrief.next?.id == first)
        precondition(ledger.focusBrief.running == nil)
        ledger.start(first, at: start)
        ledger.start(first, at: start.addingTimeInterval(5))
        precondition(ledger.active?.startedAt == start)
        precondition(ledger.focusBrief.running?.id == first)
        precondition(ledger.focusBrief.next?.id == second)
        precondition(ledger.focusBrief.spoken.contains("Next is Check oven"))
        ledger.start(second, at: start.addingTimeInterval(20))
        precondition(ledger.tasks[0].seconds == 20)
        precondition(ledger.active?.id == second)
        ledger.stop(at: start.addingTimeInterval(30))
        precondition(!ledger.tasks[1].done)
        precondition(ledger.tasks[1].seconds == 10)
        ledger.start(first, at: start.addingTimeInterval(40))
        ledger.complete(second, at: start.addingTimeInterval(60))
        precondition(ledger.active?.id == first)
        ledger.complete(first, at: start.addingTimeInterval(65))
        precondition(ledger.active == nil && ledger.tasks.allSatisfy(\.done))
        precondition(ledger.focusBrief.next == nil)
        precondition(ledger.focusBrief.completed == 2)
        precondition(ledger.tasks[0].seconds == 45)
        let data = try JSONEncoder().encode(ledger)
        let restored = try JSONDecoder().decode(WatchLedger.self, from: data)
        precondition(restored == ledger)
        print("Watch ledger tests passed")
    }
}
