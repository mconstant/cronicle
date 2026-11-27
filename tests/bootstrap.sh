#!/usr/bin/env bash
set -euo pipefail
skill='https://github.com/mconstant/cronicle/blob/test'
image="ghcr.io/mconstant/cronicle-cli@sha256:$(printf '%064d' 0)"
notes=$(bash scripts/release-notes.sh v1.0.0 "$skill" "$image")
chat=${notes%%'## Standard bootstrap'*}
standard=${notes#*'## Standard bootstrap'}
standard=${standard%%'## Developer Mode bootstrap'*}
developer=${notes#*'## Developer Mode bootstrap'}
grep -Fq 'Export Cronicle' <<< "$chat"
if grep -Eq 'docker run|ghcr\.io' <<< "$chat"; then exit 1; fi
for prompt in "$chat" "$standard" "$developer"; do
    grep -Fq 'Helper Mode and Ambient Mode are for real-time voice chats.' <<< "$(tr '\n' ' ' <<< "$prompt")"
done
for prompt in "$standard" "$developer"; do
    grep -Fq "$skill/skills/cronicle/SKILL.md" <<< "$prompt"
    grep -Fq "$image" <<< "$prompt"
    grep -Fq 'cronicle-data:/data' <<< "$prompt"
    grep -Fq 'Verify Docker setup' <<< "$prompt"
done
grep -Fq 'Enable Developer Mode' <<< "$developer"
if bash scripts/release-notes.sh v1.0.0 "$skill" latest >/dev/null 2>&1; then exit 1; fi
