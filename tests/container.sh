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

run timew track 2020-01-02T10:00:00Z to 2020-01-02T10:30:00Z Thanksgiving 'Make gravy'
run timew export :all Thanksgiving |
    python3 -c 'import json, sys; from datetime import datetime; rows = json.load(sys.stdin); assert any("Make gravy" in row["tags"] and (datetime.strptime(row["end"], "%Y%m%dT%H%M%SZ") - datetime.strptime(row["start"], "%Y%m%dT%H%M%SZ")).total_seconds() == 1800 for row in rows)'
docker run --rm -i -v "$PWD/tests/fixtures:/fixtures:ro" -e CRONICLE_FIXTURES=/fixtures \
    -e CRONICLE_LEDGER=/usr/local/lib/cronicle/ledger.py "$image" python3 - < tests/ledger.py

previous=ghcr.io/mconstant/cronicle-cli@sha256:140df5d35f1c6676f5ca79714f43d40914a0554afe42f2ea1668adbe1ecc6f15
migration_volume=$(docker volume create)
trap 'docker volume rm "$migration_volume" >/dev/null; cleanup' EXIT
docker run --rm -v "$migration_volume:/data" "$previous" task add 'Original task'
docker run --rm -v "$migration_volume:/data" "$previous" timew track 2020-01-03T10:00:00Z to 2020-01-03T10:30:00Z Legacy
docker run --rm -v "$migration_volume:/data" "$image" report all | grep -F 'Original task'
docker run --rm -v "$migration_volume:/data" "$image" report time | grep -F 'Legacy'
docker run --rm -v "$migration_volume:/data" "$image" observe '{"title":"Upgrade observation","category":"test","source":"user"}'
docker run --rm -v "$migration_volume:/data" "$image" report unresolved | grep -F 'Upgrade observation'
docker run --rm -v "$migration_volume:/data" "$previous" task export | grep -F 'Original task'
docker run --rm -v "$migration_volume:/data" "$previous" timew export :all | grep -F 'Legacy'
echo 'Cronicle container tests passed'
