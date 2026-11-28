# Cronicle capability matrix

This matrix describes the v1.5 release scope. A verified skill artifact
means its generated prompt passed checks. Host execution requires separate
evidence.

| Environment | Evidence | Cronicle-owned behavior | Host dependencies and gaps |
| --- | --- | --- | --- |
| Docker CLI and executable agent | Shell and container CI | Taskwarrior tasks, Timewarrior reports, SQLite observations, status, daily JSON, opt-in independent progress | Host needs shell access for execution and separate speech or reminder support. No host-specific inference test. |
| Linux with Python, Taskwarrior and Timewarrior | Local functional suite | Same CLI operations and report calculations | Native dependencies require installation. No desktop GUI. |
| ChatGPT Voice | Prompt checked, live v1.5 behavior untested | Conversational workflow instructions and snapshot format | Host supplies audio, turn-taking and optional notifications. Silence and persistence beyond the conversation are unverified. |
| Claude and other conversational hosts | Prompt checked, host execution untested | Chat-only workflow and snapshot instructions | Tool access, microphone, barge-in and reminders vary. |
| Codex and terminal agents | CLI verified independently of the host | Executable operations when a running instance is reachable | Agent orchestration and tool permission are host-specific. |
| Local LLMs and standalone voice gateways | Untested | Published protocol and CLI can serve as integration references | No bundled voice gateway or independent model compatibility claim. |
| Apple Watch | Simulator tests for Focus Brief and timer persistence, owner confirmed installing v1.4 build 20.1 | Offline task capture through text input, one timer, recording completion, Focus Brief and read aloud. Local JSON in UserDefaults. | System dictation and voice availability vary. Continuous microphone, conversational Helper/Ambient, milestones, progress counters, and daily schema are absent. |
| iPhone | Simulator tests of local workflows and injected transcripts | Standalone task capture and timers in local UserDefaults. One-shot voice draft and typed fallback. | Hardware mic/Bluetooth untested. iPhone TestFlight needs signing. No continuous session, milestones or sync. |
| Android and other touchscreens | Unsupported native UI | Contract applies to a future implementation | No native client shipped. |

## Watch direction

Use the display for session state, mic status, current task, and pending
changes. Turn the Digital Crown to browse tasks or review a proposal, then
tap or use an accessibility action to confirm. Offline Helper should focus on
glanceable work, quick timer transitions and progress increments. A live
Helper or Ambient session needs a verified way to receive speech. The
paired iPhone is a candidate host. Keep the task controls available when
that host is unreachable. See the [Watch acceptance criteria](apple-beta-acceptance.md).

## Conformance evidence

- Independent Human Work: synthetic 91-item fixture in the executable
  suite. Replays, corrections, invalid fields, disabled writes, persistence,
  and milestone calculations are tested. Conversational compliance and
  native controls are untested or unavailable.
- Morning household scenario: executable tests cover priority, a future
  note, dependency readiness, active work, and task completion.
- Dishwasher-style passive activity: executable tests keep elapsed
  activity separate from personal recorded time and preserve unknown times.
- Task switching and relaunch: watchOS simulator coverage. iPhone simulator
  covers relaunch and completion, plus speech draft review and fallback.
- Silent Helper, switching hosts, snapshot restoration, and cross-device
  reconciliation: written expectations. No automated host conformance claim.
