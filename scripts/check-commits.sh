#!/usr/bin/env bash
set -euo pipefail

pattern='^[a-z][a-z0-9-]*(\([^()[:cntrl:]]+\))?!?: [^[:space:]].*$'
subjects=$(git log --format='%h %s' "$1")
failed=0
while IFS=' ' read -r hash subject; do
    [[ -n $hash ]] || continue
    if [[ ! $subject =~ $pattern ]]; then
        printf 'Commit %s needs a Conventional Commit subject: %s\n' "$hash" "$subject" >&2
        failed=1
    fi
done <<< "$subjects"
exit "$failed"
