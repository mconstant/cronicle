# Resume Cronicle development

Open this file in a voice-capable coding agent, or paste the prompt below.
An agent with access to your checkout can inspect, edit, and test. A voice
agent without shell access can still discuss decisions and acceptance criteria.

```text
Help me continue development on Cronicle by voice. Read the development handoff
at https://github.com/mconstant/cronicle/blob/main/docs/development-handoff.md
and the README. If you have a checkout, inspect its status, branch, recent
commits, and relevant files. Check CI and releases before reporting what passed
or shipped. If you only have voice or chat, tell me what you can verify.

Give me a short recap of the current state and the next pending check. Then
ask what I want to work on. Treat brainstorming as discussion until I ask you
to implement. Use Ponytail and Obra's Superpowers if available. Keep changes
small, verify them, and tell me what remains untested. Pause before publishing
a release unless I've authorized it.
```

## Session digest

- Cronicle is an independent Docker project based on the workflow we liked
  in Jig. Its interactive view puts Tasksh below a live Timewarrior summary.
  Taskwarrior and Timewarrior share a persistent volume across container
  replacement. Voice and terminal should work with the same instance.
- The agent skill lives in `skills/cronicle/SKILL.md`. Starting work in
  conversation can create the task if needed and start timing. “I'm done
  for now” stops timing and leaves the task open. An explicit completion
  closes it. Use Taskwarrior UUIDs for task identity.
- Planning borrows from David Allen's Getting Things Done. Capture quickly,
  clarify the next concrete action, group related tasks in projects, and
  surface what's ready. Record genuine prerequisites as native dependencies.
  Completing a prerequisite can unblock another task. Stopping its timer
  leaves the dependency in place.
- Keep native terminal reports available verbatim in chat. In voice,
  summarize task names, meaningful statuses, and durations in ordinary
  language. The agent needs shell and Docker access to operate the app.
- The Docker integration suite checks persistence, dependencies, timer
  recording, and backfill. GitHub Actions runs it before publishing.
  See `.github/workflows/container.yml` and `tests/container.sh`.
- Release tags follow `vMAJOR.MINOR.PATCH`. A release prompt pins the skill
  commit and image digest. The README on main links to the latest release
  and includes a tested fallback. Check data compatibility and back up
  the volume before rollback.
- As of this handoff, main CI has passed. Interactive tmux and live voice
  acceptance checks are pending, and the tag-triggered release path has
  yet to be exercised. Check the current run and release state before
  assuming this is still true. The README lists the acceptance scenarios.

After a development session, update this digest when a decision or a pending
check changes. Keep account details, credentials, and raw voice transcripts
out of the public handoff.

## Commit and release notes

Use Conventional Commit subjects, such as `feat(skill): explain blocked tasks`
or `fix(container): include the Timewarrior hook`. For user-facing changes,
add a body explaining why the change was made. The pull request check
validates new commits. GitHub Releases include the commit hash, Git author,
subject, and any body since the preceding release.
