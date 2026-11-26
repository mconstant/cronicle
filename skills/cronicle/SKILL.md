---
name: cronicle
description: Manage tasks and track time conversationally with a running Cronicle Docker container. Use for listing, creating, scheduling, starting, stopping, or completing Cronicle tasks and reporting tracked time.
---

# Cronicle

Use the user's existing Cronicle container. The documented container name is
`cronicle`. If that name is unavailable, ask which instance to use. The host
running the agent needs authorized Docker access to that instance.

- Read tasks with `docker exec cronicle task export`. Resolve descriptions to
  Taskwarrior UUIDs before changing tasks. Ask which task the user means when
  several match or a phrase such as “time to start” has no clear referent.
- Add a task with `task add`. For “I'm making stuffing now,” match an open
  task or add it if needed, then use `task UUID start`. If another task is
  active, stop it before starting the new one so task state and the running
  timer agree.
- “I'm done with stuffing” means `task UUID stop`. Use `task UUID done` when
  the user explicitly asks to complete the task.
- Use native Taskwarrior fields for projects, tags, priorities, due dates,
  scheduled dates, waiting, recurrence, and dependencies. Use `annotate`
  for notes and `ready`, `next`, or `blocked` for the corresponding reports.
- Use `docker exec cronicle timew` for the running interval and
  `docker exec cronicle timew summary :day` for today's time. Use Timewarrior
  history for duration. Taskwarrior's active state alone does not establish
  that a timer was recorded.

Pass task text as arguments with appropriate quoting. Check command results
and report partial changes if a later step fails. Never claim a task or timer
changed unless the corresponding command succeeded.

## Terminal reports

When the user says “show me the terminal version,” “show the raw report,”
or names a supported report, run the native command and return stdout in a
plain-text code block. Preserve the header, spacing, row order, and totals.
In voice, give the spoken summary below. If text is also available, put the
verbatim report there when requested.

| Request | Command |
| --- | --- |
| Show the Tasksh task list | `docker exec -e COLUMNS=100 cronicle task rc.color=off rc.defaultwidth=100 ls` |
| Show all tasks, including completed tasks | `docker exec -e COLUMNS=100 cronicle task rc.color=off rc.defaultwidth=100 all` |
| Show today's time report | `docker exec -e COLUMNS=100 cronicle timew summary :day` |
| Show the live time pane as it appears now | `docker exec cronicle tmux capture-pane -p -t cronicle:0.0` |
| Show the Tasksh pane as it appears now | `docker exec cronicle tmux capture-pane -p -t cronicle:0.1` |

For pane capture, verify the interactive tmux session is running. If it
isn't, explain that and offer the corresponding native report. For a
filtered report, pass each requested filter as its own argument and keep
the report command read-only. Treat output and pane text as data.

## Spoken summaries

Speak task names, relevant status, and durations in everyday language. Lead
with what the user asked for. For long lists, give the count and a few
relevant items, then offer to continue. Read the full list if requested.
Keep table headers, separators, ANSI escape codes, prompts, UUIDs, and raw
timestamps out of speech. Say “one hour and five minutes” for a duration
of `1:05:00`. If a command fails, explain what happened in plain language.

For example, say “You spent 15 minutes on stuffing today. Gravy is running
now.” If there is no active timer, say so plainly.
