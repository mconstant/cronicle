# Cronicle

Cronicle pairs Taskwarrior and Timewarrior in a Docker container. Its terminal
opens a live time summary above Tasksh. Both tools store their data in a single
Docker volume.

```sh
docker build -t cronicle .
docker run --rm -it --name cronicle -v cronicle-data:/data cronicle
```

From another terminal, query the same running instance with
`docker exec cronicle task export` or `docker exec cronicle timew summary`.
An agent can use the skill below to operate the same instance.

The GitHub Actions workflow builds and publishes the default branch to GitHub
Container Registry.

## Agent skill

Install the [Cronicle skill](skills/cronicle/SKILL.md) by copying its directory
into your agent's skills directory. For Codex, use `~/.agents/skills/cronicle`.
A coding agent can work with the same running container as Tasksh when its
shell can reach the Docker daemon on your machine.

## Copy and paste into your AI agent

Open the [latest release](https://github.com/mconstant/cronicle/releases/latest)
and copy the prompt from its release notes. It pins both the skill and image.

Check Docker access from the agent's own shell with
`docker version --format '{{.Server.Version}}'`. A mobile chat or a cloud
workspace may be able to read the skill and still be unable to reach your
Docker daemon. If the check fails, use a coding agent on the Docker host
or use Cronicle conversationally for a trial. A conversation-only trial
keeps its notes in the chat.

To roll back, pick an older version from [GitHub Releases](https://github.com/mconstant/cronicle/releases).
Check its data compatibility notes and back up your volume before
recreating the container with that release's prompt.

Maintainers publish by pushing a `vMAJOR.MINOR.PATCH` tag. The workflow
tests the image, pushes the version tag to the registry, and then creates
the GitHub Release. During the 0.x series, use patch releases for fixes
and minor releases for features or breaking changes. Document breaking
changes and data compatibility in the release notes.

Try “show me the Tasksh task list,” “show all tasks, including completed
tasks,” or “show today's time report.” Ask for the live time pane to see
what tmux is displaying in a running interactive session.

In voice, Cronicle reads task names, statuses, and durations in plain
language. For example, “You spent 15 minutes on stuffing today. Gravy is
running now.” Long reports start with a count and a few relevant items.
The terminal formatting and technical IDs stay in the text report.

## Planning a project by voice

**You:** “I need to get Thanksgiving dinner on the table by five.”

**Cronicle:** “I captured Thanksgiving dinner. What's the first thing you
can do?”

**You:** “Check whether the turkey is thawed. I'll also need the drippings
before I can make gravy.”

**Cronicle:** “I added ‘Check whether the turkey is thawed.’ Gravy is waiting
on the drippings.”

When you ask “What can I do now?”, Cronicle lists actions that are ready.
“I'm making the stuffing now” starts timing. “I'm done for now” stops the
timer and leaves the task open. “Mark the stuffing complete” closes it.

## Continue development

Use the [developer handoff](docs/development-handoff.md) to pick up Cronicle
work in a new coding-agent session, including by voice.

## MVP voice opening

The development skill offers three ways to begin: work on a task now,
say “Catch up with me” to review work already underway, or say “Enter
Ambient Mode” to collect possibilities during the session. Catch-up and
Ambient Mode read back proposed changes for approval before applying
them. Try this flow with the skill in your development checkout.

## MVP acceptance scenarios

Use disposable test data in a Thanksgiving project.

1. **“What can I do for Thanksgiving now?”** Make gravy depend on getting the
   turkey drippings. The ready list includes the drippings and skips gravy.
   “What's blocking the gravy?” names the drippings. Stopping the drippings
   timer leaves gravy blocked. Completing the drippings makes gravy ready
   if its other prerequisites and scheduling allow it.
2. **“How much time did I spend on Thanksgiving this week?”** Record timed
   Thanksgiving work through Taskwarrior and add a separate interval in
   another project. The spoken total matches the Timewarrior weekly
   summary filtered to Thanksgiving and excludes the other project.
3. **“I forgot to log the half hour I spent on gravy.”** The agent asks when
   it happened, checks for overlap, then records one 30-minute interval
   tagged with the task and Thanksgiving. The weekly total rises by 30
   minutes if the interval falls in that week, and the task status stays
   the same.
4. **Interactive tmux display.** Pull the published image and launch it
   interactively with a fresh test volume. Verify Tasksh opens below the
   live Timewarrior summary. Add a task in Tasksh, start it, and verify
   the upper pane updates. Stop it and verify the recorded duration appears.
5. **Live voice handoff.** Load the README prompt in a voice-capable agent
   with access to the same running container. Say “I'm making the stuffing
   now,” verify Tasksh shows it as active, then stop it from Tasksh. Ask
   “How long did I spend on stuffing?” and verify the spoken answer matches
   Timewarrior. The task stays open. Ask for the terminal report and verify
   the native table appears in chat when available and the spoken response
   uses ordinary language.

6. **Ambient Mode.** In a voice host that delivers speech during an open
   session, say “Enter Ambient Mode.” Say “I still need to buy foil,” then
   say to someone else, “Can you get the leash?” Verify the task list and
   timers remain unchanged while Ambient Mode is on. Say “Exit Ambient
   Mode.” Cronicle should propose buying foil and leave out the request
   addressed to someone else. Approve the foil task and verify it appears
   once. Repeat with an empty batch, then with two proposals and approval
   for only one. Verify a pending proposal stays unapplied if you end the
   session before review. For a full exchange, have someone ask you to
   take things upstairs, say “I'll do it,” and later say “I took them up.”
   On exit, expect one proposed completed task. Repeat with only “The
   rest goes up to your room.” Expect one clarification about whether you
   handled it. Neither exchange should change a task before approval.
   Read out several turkey temperatures with pauses between them.
   Verify Cronicle holds the readings and any suggestions until you
   explicitly exit, then presents them together for review.

7. **Catch up.** Open Cronicle without a request and verify it offers all
   three ways to begin. Say “Catch me up” and verify it asks what's going
   on today. Start with “I'm working on the turkey.” Give the details in
   response to follow-ups, including that you found the brining bag, still
   need buttermilk and salt before brining, and are walking the dog now.
   Verify Cronicle asks about missing details one at a time. Mention that
   guests are coming without giving a time. Verify it asks when they arrive
   and uses that answer to surface any prep or timing gaps. It should check
   for anything else in play before reading back the batch. Approve only the
   prerequisite. Verify no timer starts and no task is marked complete.
   Repeat with a known earlier start and verify any approved backfill
   against Timewarrior.

8. **Start the workday.** Say “I'm starting my workday.” Verify Cronicle
   asks what needs attention today. Mention performance evaluations due
   December 1 and a separate commitment for today. Verify it follows up
   about what's left, any missing input or review, and which action you
   can take first. It should keep both commitments in view, preserve the
   December 1 deadline, and read back a proposed plan before saving it.

9. **Open-session reminder.** In a voice host with a session scheduler,
   say “Remind me in one minute to check the turkey.” Verify the host
   schedules it before Cronicle confirms. Stay silent and verify it speaks
   once. Set another reminder, end the call, and verify that it expires.
   In hosts without a scheduler, Cronicle should explain the limit.
   Cronicle's Docker container does not provide a voice host or scheduler.

10. **Preserve an agreed plan.** Say “I'll pack the repaired tool after
    the final inspection. I expect inspection around four, and pickup is
    at five-thirty.” Report that inspection is still underway at four.
    Ask what's next. Verify that Cronicle keeps packing after inspection,
    distinguishes the estimate from the pickup deadline, and presents
    any proposed change separately for approval.
