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
ambiguous. When I ask for a terminal report, use the skill's native commands
and show the output verbatim in a plain-text code block. If you don't have
shell or Docker access, tell me and give me the commands to run.
```

The prompt works as instructions in any chat. To act on your tasks, the agent
needs access to the host running Cronicle and permission to use Docker.

Try “show me the Tasksh task list,” “show all tasks, including completed
tasks,” or “show today's time report.” Ask for the live time pane to see
what tmux is displaying in a running interactive session.
