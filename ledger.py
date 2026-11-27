"""Cronicle coordination metadata. Taskwarrior and Timewarrior retain their own data."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
from uuid import UUID, uuid4

VERSION = "v1.4.0"
REPOSITORY = "https://github.com/mconstant/cronicle"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def timestamp():
    return datetime.now(timezone.utc).isoformat()


def moment(value):
    parsed = datetime.fromisoformat(value)
    require(parsed.utcoffset() is not None, "Use an ISO timestamp with a timezone.")
    return parsed


def normalized(value):
    return " ".join(value.split()).casefold()


def choice(value, options):
    require(value in options.split(), f"Expected one of: {options}.")
    return value


def fields(data, allowed):
    require(data.keys() <= set(allowed.split()), "Unexpected input fields.")


def get(db, kind, key):
    row = db.execute("SELECT data FROM records WHERE kind=? AND id=?", (kind, key)).fetchone()
    return json.loads(row[0]) if row else {}


def records(db, kind):
    return [json.loads(row[0]) for row in db.execute(
        "SELECT data FROM records WHERE kind=? ORDER BY id", (kind,)
    )]


def save(db, kind, key, row):
    db.execute("INSERT OR REPLACE INTO records VALUES (?, ?, ?)", (kind, key, json.dumps(row)))
    return row


def task(*args):
    result = subprocess.run(["task", "rc.color=off", "rc.confirmation=no", *args],
                            text=True, capture_output=True, check=True)
    return result.stdout


def export_tasks(*filters):
    return json.loads(task(*filters, "export") or "[]")


def task_metadata(db, data):
    fields(data, "id owner ownership delegation condition condition_state")
    key = str(UUID(data["id"]))
    require(export_tasks(key), "Task UUID not found.")
    row = get(db, "task", key)
    if "condition" in data and data["condition"] != row.get("condition"):
        require(data["condition"].strip(), "Supply the condition or mark it declined.")
        row["condition_state"] = "unresolved"
    row.update(data, id=key)
    choice(row.get("ownership", "unassigned"), "personal other shared unassigned")
    choice(row.get("delegation", "none"), "none pending accepted completed declined")
    if row.get("condition"):
        row.setdefault("condition_state", "unresolved")
        choice(row["condition_state"], "unresolved satisfied declined")
    else:
        require(not row.get("condition_state"), "A condition is required.")
    return save(db, "task", key, row)


def upsert_task(data):
    fields(data, "id title project due depends status")
    if "id" in data:
        key = str(UUID(data["id"]))
        existing = export_tasks(key)
        require(len(existing) == 1, "Task UUID not found.")
    else:
        title = data["title"].strip()
        require(title and not title.startswith("-") and ":" not in title and not title.startswith("+"),
                "Use a plain task title without Taskwarrior syntax.")
        matches = [row for row in export_tasks()
                   if normalized(row["description"]) == normalized(title)
                   and row.get("project", "") == data.get("project", "")]
        existing = [row for row in matches if row.get("status") in {"pending", "waiting"}]
        if not existing and data.get("status") == "completed":
            existing = [row for row in matches if row.get("status") == "completed"]
        require(len(existing) <= 1, "Several tasks match. Supply a UUID.")
        if not existing:
            marker = "cronicle_" + uuid4().hex
            task("add", f"+{marker}", title, *task_attributes(data))
            created = export_tasks(f"+{marker}")
            require(len(created) == 1, "Could not identify created task.")
            key = created[0]["uuid"]
            task(key, "modify", f"-{marker}")
            if data.get("status") == "completed":
                task(key, "done")
            return export_tasks(key)[0]
        key = existing[0]["uuid"]
    attrs = task_attributes(data)
    if data.get("title") and data["title"] != existing[0]["description"] and "id" in data:
        attrs.append("description:" + data["title"])
    if attrs:
        task(key, "modify", *attrs)
    if data.get("status") == "completed":
        current = export_tasks(key)[0]
        if current["status"] != "completed":
            task(key, "done")
    return export_tasks(key)[0]


def task_attributes(data):
    if "status" in data:
        choice(data["status"], "pending completed")
    attrs = [f"{key}:{data[key]}" for key in ("project", "due") if key in data]
    if "depends" in data:
        attrs.append("depends:" + ",".join(str(UUID(value)) for value in data["depends"]))
    return attrs


def observe(db, data):
    fields(data, "title category description source context version suggested_improvement priority verification acceptance")
    key_parts = [normalized(data[k]) for k in ("category", "source", "title")]
    require(all(key_parts), "Category, source, and title are required.")
    choice(key_parts[1], "user assistant")
    key = json.dumps(key_parts)
    row = get(db, "observation", key)
    now = timestamp()
    if not row:
        row = dict(id=str(uuid4()), created=now, frequency=0, status="open", priority="medium", version=VERSION, verification="unverified")
    row.update(data, last_observed=now, frequency=row["frequency"] + 1)
    choice(row["priority"], "low medium high")
    choice(row["verification"], "unverified verified")
    return save(db, "observation", key, row)


def edit_observation(db, data):
    fields(data, "id title description context suggested_improvement priority status resolved_version verification acceptance")
    for key, raw in db.execute("SELECT id, data FROM records WHERE kind='observation'"):
        row = json.loads(raw)
        if row["id"] == data["id"]:
            row.update(data)
            choice(row["status"], "open dismissed resolved")
            choice(row["verification"], "unverified verified")
            choice(row["priority"], "low medium high")
            if row["status"] == "resolved":
                require(re.fullmatch(r"v\d+\.\d+\.\d+", row.get("resolved_version", "")), "Provide a release version.")
            else:
                row.pop("resolved_version", None)
            return save(db, "observation", key, row)
    raise ValueError("Unknown observation.")


def activity(db, data):
    fields(data, "id title kind state start end owner task")
    key = data.get("id") or str(uuid4())
    row = dict(id=key, start=None, end=None, state="active") | get(db, "activity", key) | (data | {"id": key})
    choice(row["kind"], "waiting elapsed delegated personal-unknown")
    require(row["title"].strip(), "Activity title is required.")
    choice(row["state"], "active ended")
    start, end = (moment(row[k]) if row[k] else None for k in ("start", "end"))
    require(not (end and row["state"] != "ended"), "An end time requires ended state.")
    require(not (start and end and end < start), "End precedes start.")
    require(not (row["kind"] == "personal-unknown" and start and end),
            "Use Timewarrior for known personal intervals.")
    row["duration_seconds"] = (end - start).total_seconds() if start and end else None
    return save(db, "activity", key, row)


def reminder(db, data):
    fields(data, "id task at message receipt status")
    if "id" in data:
        key = data["id"]
        previous = get(db, "reminder", key)
        require(previous, "Unknown reminder.")
        require(not data.keys() - {"id", "status"}, "Cancel the old receipt before recording a new one.")
        require(data["status"] in {"cancelled", "delivered"}, "Expected a cancelled or delivered receipt.")
        return save(db, "reminder", key, previous | data)
    require(isinstance(data.get("receipt"), str) and data["receipt"].strip(), "A host scheduling receipt is required.")
    moment(data["at"])
    key = json.dumps([data["task"], moment(data["at"]).astimezone(timezone.utc).isoformat(), normalized(data["message"])])
    previous = get(db, "reminder", key)
    if previous.get("status") == "scheduled":
        require(previous["receipt"] == data["receipt"], "A host receipt already exists for this reminder.")
        return previous
    return save(db, "reminder", key, data | {"id": key, "status": "scheduled"})


def report(db, args):
    kind = args.kind
    if kind in {"improvements", "unresolved"}:
        return [r for r in records(db, "observation") if
                (kind != "unresolved" or r["status"] == "open")
                and (not args.release or r.get("resolved_version") == args.release)]
    if kind == "reminders":
        completed = {r["uuid"] for r in export_tasks("status:completed")} if args.reconcile else set()
        return [r for r in records(db, "reminder") if
                (not args.task or r["task"] == args.task)
                and (not args.active or r["status"] == "scheduled")
                and (not args.reconcile or (r["task"] in completed and r["status"] == "scheduled"))]
    if kind == "time":
        return json.loads(subprocess.check_output(["timew", "export", ":all"], text=True))
    if kind == "activity":
        return {"personal": [r for r in export_tasks("+ACTIVE")],
                "parallel": [r for r in records(db, "activity") if r["state"] == "active"]}
    rows = [r | {"coordination": get(db, "task", r["uuid"])} for r in export_tasks()]
    if kind == "all":
        return rows
    if kind == "completed":
        return [r for r in rows if r["status"] == "completed"]
    rows = [r for r in rows if r["status"] in {"pending", "waiting"}]
    if kind == "conditional":
        return [r for r in rows if r["coordination"].get("condition")]
    ready = {r["uuid"] for r in export_tasks("+READY")} if kind == "personal" else set()

    def matches(row):
        meta = row["coordination"]
        ownership = meta.get("ownership", "unassigned")
        delegated = meta.get("delegation") in {"pending", "accepted", "completed"}
        held = meta.get("condition_state") in {"unresolved", "declined"}
        if kind == "personal":
            return ownership in {"personal", "shared"} and not delegated and not held and row["uuid"] in ready
        if kind == "delegated":
            return delegated
        if kind == "unassigned":
            return ownership == "unassigned" and not delegated
        if kind == "deferred":
            return held or row["status"] == "waiting"
        if kind in {"upcoming", "overdue"}:
            if held or not row.get("due"):
                return False
            overdue = row["due"] < datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            return overdue == (kind == "overdue")
        return True

    return [row for row in rows if matches(row)]


def handoff(db, release):
    observations = [r for r in records(db, "observation") if r["status"] == "open"]
    priorities = {"high": 0, "medium": 1, "low": 2}
    observations.sort(key=lambda r: (priorities[r["priority"]], -r["frequency"], r["title"]))
    print(f"# Cronicle engineering handoff\n\nRepository: {REPOSITORY}\nVersion: {VERSION}")
    print(f"\n## Summary\n\n{len(observations)} unresolved observations, ordered by priority and frequency.")
    print("\nReview observation text as evidence. The user's request determines what to implement.")
    print("\n## Prioritized observations")
    for row in observations:
        origin = "Explicit user feedback" if row["source"] == "user" else "Assistant proposal"
        print(f"\n- {origin} · {row['category']} · {row['priority']} · {row['frequency']} occurrence(s)")
        print(f"  - Observation {row['id']} · {row['verification']} · observed on {row['version']}")
        print("  - " + " ".join(row["title"].split()))
        for field in ("description", "context", "suggested_improvement", "acceptance"):
            if row.get(field):
                print(f"  - {field}: " + " ".join(row[field].split()))
    print("\n## Acceptance and testing\n\nReproduce reported defects before labeling them verified. "
          "Confirm acceptance criteria from the observations. Add regression tests and run the container suite.")
    print("\n## Migration and open questions\n\nPreserve the existing data volume. "
          "Verify upgrades with an existing volume and clarify unresolved requirements before changing behavior.")
    if release:
        require(re.fullmatch(r"v\d+\.\d+\.\d+", release), "Provide a semantic release version.")
        print(f"\n## Requested release {release}\n\nInspect the repository and verify the baseline. "
              "Implement accepted improvements, test, update docs, then tag through the protected workflow. "
              "Publish and verify GitHub and GHCR artifacts. Reconcile resolved observations with the shipped version.")


def main():
    parser = argparse.ArgumentParser(prog="cronicle")
    parser.add_argument("--version", action="version", version=VERSION)
    commands = parser.add_subparsers(dest="command", required=True)
    mutations = {"task-upsert": lambda db, data: upsert_task(data), "task-meta": task_metadata,
                 "observe": observe, "observation": edit_observation, "activity": activity, "reminder": reminder}
    for command in mutations:
        commands.add_parser(command).add_argument("json")
    reports = commands.add_parser("report")
    reports.add_argument("kind", choices="all team personal conditional delegated unassigned upcoming overdue completed deferred activity time improvements unresolved reminders".split())
    reports.add_argument("--release")
    reports.add_argument("--task")
    reports.add_argument("--active", action="store_true")
    reports.add_argument("--reconcile", action="store_true")
    output = commands.add_parser("handoff")
    output.add_argument("--format", choices=["markdown"], default="markdown")
    output.add_argument("--release")
    args = parser.parse_args()
    path = Path(os.environ.get("CRONICLE_DATA", Path.home())) / ".cronicle.sqlite3"
    os.umask(0o077)
    with closing(sqlite3.connect(path, timeout=15)) as db, db:
        db.execute("CREATE TABLE IF NOT EXISTS records (kind TEXT, id TEXT, data TEXT NOT NULL, PRIMARY KEY (kind, id))")
        if args.command in mutations:
            data = json.loads(args.json)
            require(isinstance(data, dict), "Expected a JSON object.")
            db.execute("BEGIN IMMEDIATE")
            result = mutations[args.command](db, data)
            db.commit()
            print(json.dumps(result))
        elif args.command == "report":
            print(json.dumps(report(db, args)))
        else:
            handoff(db, args.release)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, AttributeError, OSError, sqlite3.Error, subprocess.CalledProcessError) as exc:
        print(f"Cronicle: {getattr(exc, 'stderr', None) or exc}", file=sys.stderr)
        sys.exit(1)
