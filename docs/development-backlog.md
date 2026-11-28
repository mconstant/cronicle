# Development backlog

- **P0 · Verify live Silent Helper.** Exercise explicit mode transitions,
  partial utterances, unrelated speech, no-op turns, completion evidence,
  and Independent Human Work on a real voice host. Record host and model
  versions, missed updates, acknowledgments, and incorrect interruptions.
- **P1 · Portable execution and restoration.** Define a shared event envelope
  and a validated snapshot/restore protocol with stable identities. Compare
  Taskwarrior/SQLite and Swift outcomes on the same fixture before claiming
  parity. Include explicit timer boundary provenance and local-day reporting.
- **P1 · Watch Helper.** Prototype opt-in voice sessions with a visible
  connection/mic state. Validate stop, connection recovery, and review on a
  physical Watch. Keep the display and Digital Crown acceptance criteria.
- **P1 · Native administrative controls.** Add defer, increment/correct
  progress, milestone review, and portable reports to Watch and iPhone.
  Verify the same 91-item scenario. Verify signed iPhone TestFlight when
  its App Store Connect record and provisioning profile are available.
- **P2 · Host expansion.** Verify chat snapshot restoration and cross-host
  handoff, then test local LLM/voice gateways and additional touchscreen UIs.
  Specify conflict handling before shipping synchronization.
- **P2 · Reporting.** Add Markdown and compact native renderers against
  the canonical JSON corpus. Add coverage windows before reporting
  untracked time. Carry unknown and estimated values through every renderer.
