#!/usr/bin/env bash
set -euo pipefail

image=${1:-cronicle}
volume=
cleanup() {
    if [[ -n "$volume" ]]; then
        docker volume rm "$volume" >/dev/null
    fi
}
trap cleanup EXIT
volume=$(docker volume create)
run() {
    docker run --rm -v "$volume:/data" "$image" "$@"
}

run task add project:Thanksgiving Get turkey drippings
run task add project:Thanksgiving Make gravy depends:1
run task project:Thanksgiving ready | grep -F 'Get turkey drippings'
run task project:Thanksgiving blocked | grep -F 'Make gravy'

run task 1 start
run timew | grep -F 'Get turkey drippings'
sleep 2
run task 1 stop
run task project:Thanksgiving blocked | grep -F 'Make gravy'
run timew summary :week Thanksgiving | grep -F 'Get turkey drippings'

run task 1 done
run task project:Thanksgiving ready | grep -F 'Make gravy'

run timew track 2h ago for 30min Thanksgiving 'Make gravy'
run timew export :all Thanksgiving |
    python3 -c 'import json, sys; from datetime import datetime; rows = json.load(sys.stdin); assert any("Make gravy" in row["tags"] and (datetime.strptime(row["end"], "%Y%m%dT%H%M%SZ") - datetime.strptime(row["start"], "%Y%m%dT%H%M%SZ")).total_seconds() == 1800 for row in rows)'
echo 'Cronicle container tests passed'
