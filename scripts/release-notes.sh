#!/usr/bin/env bash
set -euo pipefail

version=$1
source_url=$2
image=$3
if [[ ! $version =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ||
      ! $image =~ @sha256:[0-9a-f]{64}$ ]]; then
    echo 'Expected a vMAJOR.MINOR.PATCH tag and an image digest.' >&2
    exit 1
fi

cat <<NOTES
## Start in chat

Paste this block into your AI chat or voice-capable agent. It is self-contained.

\`\`\`text
Use Cronicle $version.
NOTES
awk 'BEGIN { markers = 0 } /^---$/ && markers < 2 { markers++; next } markers == 2 { print }' skills/cronicle-chat/SKILL.md
cat <<NOTES
\`\`\`
NOTES

docker_prompt() {
    local variant=$1
    printf '\n## %s\n\n' "$variant"
    cat <<NOTES
\`\`\`text
Use Cronicle $version to manage my tasks and track time.
Load the skill from $source_url/skills/cronicle/SKILL.md.
Use the Docker image $image.

Check Docker access from your shell with docker version --format '{{.Server.Version}}'.
If Cronicle is already running, check its image and ask before replacing it.
Back up and preserve the existing cronicle-data volume before switching versions.
Ask before starting a new installation:

docker run --rm -it --name cronicle -v cronicle-data:/data $image

Verify Docker setup and persistence before reporting success. If Docker is
unavailable, offer the Start in chat prompt or give me the command for a
persistent Docker host. Show native reports in chat and summarize them in
voice. Confirm changes and reminders only after successful execution.
If I haven't given you a task, offer a ready action or ask what I want to
accomplish today.
NOTES
    if [[ $variant == 'Developer Mode bootstrap' ]]; then
        cat <<'NOTES'

Enable Developer Mode alongside normal operation. Quietly persist bugs,
limitations, feature requests, workflow friction, corrections, and
improvement suggestions. Distinguish my explicit feedback from your
recommendations. Verify persistence before confirming. On request, generate
a self-contained Markdown engineering handoff with priorities, supporting
observations, recommendations, and acceptance criteria. For a requested
release handoff, include implementation, test, build, publication, and
verification steps for the requested version. Generating a handoff itself
does not edit source code or publish a release.
NOTES
    fi
    printf '\x60\x60\x60\n'
}

docker_prompt 'Standard bootstrap'
docker_prompt 'Developer Mode bootstrap'
