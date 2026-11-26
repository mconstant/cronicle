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
An agent with shell tools and Docker access can then work with the same
running container as Tasksh. Voice depends on the agent's own voice interface.

## Copy and paste into your AI agent

```text
Use Cronicle to help me manage tasks and track time. Read the README and
skills/cronicle/SKILL.md at https://github.com/mconstant/cronicle.

If you have shell access and can reach Docker, look for my existing Cronicle
container and use it. If I haven't set one up yet, walk me through the README's
setup or ask before building and starting the container. Keep my tasks and time
history in the persistent cronicle-data volume.

Use the skill to interpret everyday requests like “I'm making stuffing now,”
“I'm done with stuffing,” or “How long did I spend on it?” Ask when the task is
ambiguous. When I ask for a terminal report, use the skill's native commands.
Show the output verbatim in chat and summarize it conversationally in voice.
If you don't have shell or Docker access, tell me and give me the commands
to run.
```

The prompt works as instructions in any chat. To act on your tasks, the agent
needs access to the host running Cronicle and permission to use Docker.

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
