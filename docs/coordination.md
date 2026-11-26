# Coordination and improvement log

Run these examples with an existing Cronicle container.

```sh
docker exec cronicle cronicle --version
docker exec cronicle cronicle report activity
docker exec cronicle cronicle report personal
docker exec cronicle cronicle report team
docker exec cronicle cronicle report delegated
docker exec cronicle cronicle report conditional
docker exec cronicle cronicle report upcoming
docker exec cronicle cronicle report unresolved
docker exec cronicle cronicle report improvements --release v1.0.0
docker exec cronicle cronicle handoff --format markdown
```

Use `cronicle report --help` for the full report list. Use the standard
bootstrap for ordinary voice use or the Developer Mode bootstrap to opt
into improvement capture. The [skill](../skills/cronicle/SKILL.md) shows
the JSON payload fields. Existing tasks without an assigned owner are
unassigned. Tasksh retains its native reports. Use Cronicle reports for
ownership, conditional readiness, and conditional deadline filtering.

Developer Mode stores a concise observation only when a connected agent
executes the command. A chat-only agent can export its observations in
a snapshot. Git release creation cannot modify a user's Docker volume.
Review affected observation IDs on that installation, then mark verified
fixes as resolved with the shipped version. Unrelated observations stay open.

## Anonymized Thanksgiving trial

During dinner prep a coordinator tracked a cooking deadline and heard a
family member request help. The team needed to retrieve equipment, decide
whether to set up a remote gateway if requested, and coordinate cleanup
while the food cooked. Equipment repair finished during the conversation.
The first Ambient Mode test missed a fragmented commitment and another
test spoke repeatedly while the coordinator was using their hands.

For acceptance testing, have a helper own oven monitoring and the
coordinator own retrieving probes. Set up the gateway only if requested.
Record cooking as elapsed activity, delegated monitoring separately, and
cleanup as personal effort. Say “I’ll repair the tool” and later “I put
the spring back in.” The first statement establishes intent, the second
establishes completion. In Helper Mode, the skill applies supported
updates quietly. In Ambient Mode, it presents the changes at exit.

Ask what’s in play and verify the cooking deadline, ready equipment task,
and delegated monitoring. Confirm the gateway stays out of actionable and
overdue reports until activated. Finish early and reconcile a scheduled
reminder using a capable host. With Developer Mode enabled, report
repeated spoken acknowledgments and generate a developer handoff. Verify
the observation count increases while ordinary tasks remain separate.

The container suite exercises the native state changes with a disposable
volume. A live voice host is required to evaluate interruptions, speech
delivery, and real notification cancellation.

## Trial findings addressed in v1.0.0

- Repeated spoken acknowledgments → quiet Helper Mode instructions.
- Missing ownership and conditional work → coordination metadata and reports.
- Parallel cooking and cleanup → separate activity tracking and personal time.
- Missing feedback trail → persistent observations and Markdown handoffs.
- Reminder completion → host receipt tracking and reconciliation candidates.

The live voice behavior and host notification integration remain subject
to testing on a compatible host.
