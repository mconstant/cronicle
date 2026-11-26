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
