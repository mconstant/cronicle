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
## Copy and paste into your AI agent

\`\`\`text
Use Cronicle $version to manage my tasks and track time.
Load the skill from $source_url/skills/cronicle/SKILL.md.
Use the Docker image $image.

If Cronicle is already running, check its image and ask before replacing it.
Keep my task and time data in the existing volume and back it up before
switching versions. For a new setup, ask before starting this container:

docker run --rm -it --name cronicle -v cronicle-data:/data $image

If you cannot access Docker on the host, give me the commands to run.
Show native terminal reports in chat and summarize them in voice.
\`\`\`
NOTES
