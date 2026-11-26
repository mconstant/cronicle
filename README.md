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
Voice integration is planned.

The GitHub Actions workflow builds and publishes the default branch to GitHub
Container Registry.
