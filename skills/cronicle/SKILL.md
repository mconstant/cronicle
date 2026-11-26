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
