# Cronicle experience and execution contract v1

Contract v1 describes observable behavior. The JSON status and daily report
each carry their own `schema_version: 1`. Producers can add optional fields.
Consumers should retain unknown fields if they store or forward a report.

## Execution and host capabilities

| Tier | Who applies changes | State and clock |
| --- | --- | --- |
| Conversational | The loaded skill guides LLM interpretation of user input | Chat-local task state. Snapshot export is explicit. Use host time only when available and identify reported, estimated, and unknown boundaries. |
| Executable | Cronicle validates structured operations, then uses SQLite, Taskwarrior, and Timewarrior | Local files, normally in the mounted Docker volume. Reports use the executable clock and source timestamps. |
| Native on-device | The Apple app applies local task and timer changes | Per-device storage and clock. Sync and the executable report contract are future work. |

Host speech, turn detection, barge-in, notifications, rich rendering and
authorizations are independent of the tier. An adapter should identify its
input source, operation proposal, applied result, state location and clock
source. It should advertise a host capability only after checking it and
treat host confirmation of a reminder as a receipt. No plugin system is
required to use this interface.

Run `docker exec cronicle cronicle status` or `python3 ledger.py status`.
The executable reports its version, native version probes, SQLite path,
Taskwarrior configuration and resolved data location where available, and
any Timewarrior directory override. A null location means the executable
did not resolve it. The bundled container initializes Taskwarrior and
Timewarrior under `/data`. A version probe establishes that a component
responds. A successful command establishes execution of that command.
Host capabilities are explicitly unprobed by the CLI. The executable's
storage persists as long as its underlying volume or directory persists.
Ending a chat does not stop a native timer.

## Core behavior

| Capability | Observable behavior |
| --- | --- |
| Capture and clarify | Capture quickly with an explicit title. Match an existing task in its project. Resolve ambiguity before a write. |
| Organize and prioritize | Preserve the user's project, due date, priority, and dependencies. Keep a new future note from stealing an active timer. |
| Start, pause, resume, complete | Identify the current personal action. A switch closes the prior interval at the boundary. A pause leaves the task open. Completion requires evidence. |
| Next action | Separate ready, blocked, deferred, and completed work. Keep unresolved conditions and delegated work out of personal ready actions. |
| Passive activities | Keep elapsed, waiting, and delegated time separate from personal effort. |
| Interruptions and catch-up | Maintain the primary objective across topics. Ask material follow-ups and apply approved catch-up changes. Preserve unknown start or end times. |
| Daily report | Show current work, ready actions, blockers and recorded intervals, with an explicit report window. Give concise spoken output when supported. |
| Portability | Chat supports explicit snapshot export and restoration. Executable JSON reports are readable outside the host. Preserve the container volume for full executable state, including the native databases. |

## Enhanced interactions

| Enhancement | Required behavior and fallback |
| --- | --- |
| Helper | An opted-in real-time voice host can apply supported updates quietly. Use explicit task controls without one. |
| Ambient | Opt-in real-time speech produces a review batch. No batch changes apply before approval. |
| Silent Helper | Requires a real-time voice host. Skip routine acknowledgments and partial utterances. If the host requires output, use its least intrusive response. Report material failures when appropriate. |
| Independent Human Work | Explicit opt-in restricts assistance to administration across mode changes. Keep counts, milestones, and compensation terms. Decline substantive assignment assistance. |
| Developer Mode | Opt-in keeps improvement observations separate from user tasks. Capture evidence and generate handoffs without initiating development or release. |
| Notifications | Show due times by default. Schedule only with a working host capability and confirmation. |
| Touchscreen and Watch | Offer explicit capture, start, pause, resume, complete, defer, progress, review and report controls where implemented. Preserve the same state transitions. |

The voice host controls interruptions, audio focus, partial delivery,
silence, and full duplex. Cronicle's skill controls the interpretation of
delivered turns. Discard unrelated speech and weak evidence. Explicitly
correct existing tasks rather than creating duplicates. A future test
harness should record missed updates, unsupported changes, spoken
acknowledgments, and false interrupts. Simulated transcripts cannot prove
audible silence or real latency.

## Independent Human Work

Independent work uses an opt-in, installation-controlled flag.
`CRONICLE_FEATURE_INDEPENDENT_WORK` is off by default. Set it to `on` for
the process that invokes Cronicle to enable structured writes. For a running
container, use `docker exec -e CRONICLE_FEATURE_INDEPENDENT_WORK=on cronicle
cronicle ...` on authorized writes. For sustained opt-in, set the variable
when launching the container. There is no remote flag service.

Absent, off, or invalid settings deny writes. A disabled flag leaves reports
and existing records accessible, and leaves task and timer commands
available. A conversational mode toggle cannot change deployment flags.
Flags are checked in the command handler at execution and independent of the
CLI transport. Add future flags at feature entry points with tests for
default behavior and rollback. Avoid using a feature flag as an access
control boundary.

The synthetic exercise has 91 items, with 40 and 51 in the two stages, an
expected 180–300 minutes, and two $100 milestones. Targets are cumulative.
Amounts are integers in the currency's minor units.

```sh
export CRONICLE_FEATURE_INDEPENDENT_WORK=on
python3 ledger.py work '{"id":"independent-91","title":"Independent Research","total":91,"expected_minutes":[180,300],"currency":"USD","milestones":[{"target":40,"amount_minor":10000},{"target":91,"amount_minor":10000}]}'
python3 ledger.py work '{"id":"independent-91","completed":40}'
python3 ledger.py work '{"id":"independent-91","completed":39,"correction":true}'
python3 ledger.py report work
```

Use a stable ID and absolute completed count. A retry does not increment
anything. A conflicting definition or invalid count fails without changing
the record. A decrease requires an explicit correction. The reached amount
is an administrative calculation and does not indicate payment. Use short
generic titles and never place assignment material in tracking fields.

## Canonical daily JSON

Run `docker exec cronicle cronicle report daily --day 2026-11-28`.
If no day is supplied, the command uses today's UTC date.

| Field | Meaning |
| --- | --- |
| `window` | Inclusive start and exclusive end in UTC. |
| `current_activity` | Current native task state and open intervals that intersect that window. |
| `tasks` | Ready, blocked, and deferred queues from the current snapshot plus completions in the chosen day. No historical task queue reconstruction. |
| `personal_time` | Timewarrior intervals with original boundaries and a union of closed intervals clipped to the window. Open intervals are excluded from the total. |
| `passive_activities` | Intersecting or undated activity records. Boundaries can be reported, estimated, unclassified or unknown. A reported duration can include estimates and is never added to personal time. |
| `independent_work` | Current progress and milestone outcomes with estimates and integer currency amounts. |
| `untracked_intervals` | Null without an agreed coverage window. A gap alone does not prove inactivity. |
| `provenance` | Native data source, executable calculations and scope of the snapshot. |

Native history has unclassified boundary origin because Timewarrior stores
both live and backfilled intervals in the same format. The calculated total
describes recorded time. It does not prove how the times were obtained.
Renderers should preserve this distinction. The CLI produces JSON or a plain-text summary with
`--format text`. The skills can render summaries from the same data. Native terminal reports remain available.
