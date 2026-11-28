"""Cronicle coordination metadata. Taskwarrior and Timewarrior retain their own data."""
import argparse
from contextlib import closing
from datetime import date, datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
from uuid import UUID, uuid4

VERSION = "v1.5.0"
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
    fields(data, "id title project due depends status priority wait")
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
    if "priority" in data:
        require(data["priority"] in ("", "H", "M", "L"), "Expected priority H, M, L, or empty.")
    attrs = [f"{key}:{data[key]}" for key in ("project", "due", "priority", "wait") if key in data]
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
    fields(data, "id title kind state start end owner task start_source end_source")
    key = data.get("id") or str(uuid4())
    existing = get(db, "activity", key)
    row = dict(id=key, start=None, end=None, state="active") | existing | (data | {"id": key})
    choice(row["kind"], "waiting elapsed delegated personal-unknown")
    require(row["title"].strip(), "Activity title is required.")
    choice(row["state"], "active ended")
    start, end = (moment(row[k]) if row[k] else None for k in ("start", "end"))
    require(not (end and row["state"] != "ended"), "An end time requires ended state.")
    require(not (start and end and end < start), "End precedes start.")
    require(not (row["kind"] == "personal-unknown" and start and end),
            "Use Timewarrior for known personal intervals.")
    for boundary in ("start", "end"):
        source = boundary + "_source"
        if boundary in data and data[boundary] != existing.get(boundary) and source not in data:
            row.pop(source, None)
        if row[boundary] is None:
            require(data.get(source, "unknown") == "unknown", "A timestamp source requires a timestamp.")
            row[source] = "unknown"
        else:
            row[source] = choice(row.get(source, "unclassified"), "reported estimated unclassified")
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


FEATURE_FLAGS = {"independent_work": "CRONICLE_FEATURE_INDEPENDENT_WORK"}


def feature_setting(name):
    setting = os.environ.get(FEATURE_FLAGS[name], "off").casefold()
    return setting if setting in {"on", "off"} else "invalid"


def feature_enabled(name):
    return feature_setting(name) == "on"


def work(db, data):
    require(feature_enabled("independent_work"),
            "Independent work writes are disabled. Set CRONICLE_FEATURE_INDEPENDENT_WORK=on to enable them.")
    key = data["id"]
    require(isinstance(key, str) and re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}", key),
            "Supply a stable work ID.")
    row = get(db, "work", key)
    if "title" in data:
        fields(data, "id title total expected_minutes currency milestones")
        fields_set = set("id title total expected_minutes currency milestones".split())
        require(data.keys() == fields_set, "Provide the full administrative work definition.")
        title, total, minutes, currency, milestones = (data[field] for field in
            ("title", "total", "expected_minutes", "currency", "milestones"))
        require(isinstance(title, str) and 0 < len(title.strip()) <= 120 and "\n" not in title,
                "Provide a single-line administrative title of at most 120 characters.")
        require(type(total) is int and total > 0, "Total must be a positive item count.")
        require(isinstance(minutes, list) and len(minutes) == 2
                and all(type(value) is int for value in minutes) and 0 < minutes[0] <= minutes[1],
                "Expected minutes must be an ordered pair of positive integers.")
        require(isinstance(currency, str) and re.fullmatch(r"[A-Z]{3}", currency),
                "Supply a three-letter currency code.")
        require(isinstance(milestones, list), "Expected a milestone array.")
        previous = 0
        for milestone in milestones:
            require(isinstance(milestone, dict) and milestone.keys() == {"target", "amount_minor"},
                    "Milestones contain target and amount_minor only.")
            target, amount = milestone["target"], milestone["amount_minor"]
            require(type(target) is int and previous < target <= total and type(amount) is int and amount >= 0,
                    "Milestone targets must increase and amounts must be nonnegative minor units.")
            previous = target
        if row:
            require(all(row[field] == data[field] for field in fields_set),
                    "This work ID already has a different definition.")
            return row
        row = data | {"completed": 0}
    else:
        fields(data, "id completed correction")
        require(row, "Unknown work ID.")
        count = data["completed"]
        correction = data.get("correction", False)
        require(type(count) is int and 0 <= count <= row["total"], "Completed count is outside the work total.")
        require(type(correction) is bool, "Correction must be true or false.")
        require(count >= row["completed"] or correction, "A decrease requires an explicit correction.")
        if count == row["completed"]:
            return row
        row["completed"] = count
    row["remaining"] = row["total"] - row["completed"]
    row["reached_amount_minor"] = sum(m["amount_minor"] for m in row["milestones"]
                                      if m["target"] <= row["completed"])
    return save(db, "work", key, row)


def executable_status(path):
    components = {}
    for name, executable in (("taskwarrior", "task"), ("timewarrior", "timew")):
        try:
            result = subprocess.run([executable, "--version"], text=True, capture_output=True,
                                    timeout=5, check=True)
            components[name] = {"available": True, "version": result.stdout.strip().splitlines()[0]
                                if result.stdout.strip() else None}
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            components[name] = {"available": False, "version": None}
    task_location = os.environ.get("TASKDATA")
    if components["taskwarrior"]["available"] and task_location is None:
        try:
            task_location = subprocess.check_output(["task", "_get", "rc.data.location"],
                                                    text=True, stderr=subprocess.DEVNULL, timeout=5).strip() or None
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
    return {
        "schema_version": 1, "version": VERSION, "execution_tier": "executable",
        "components": {"cronicle": {"available": True, "version": VERSION}, **components},
        "state": {
            "coordination": {"backend": "sqlite", "location": str(path.resolve())},
            "tasks": {"backend": "taskwarrior", "location": task_location,
                      "configuration": os.environ.get("TASKRC", str(Path.home() / ".taskrc"))},
            "time": {"backend": "timewarrior", "location": os.environ.get("TIMEWARRIORDB")},
            "session_end": "Data remains on disk. Ending a chat does not stop an active timer.",
        },
        "feature_flags": {name: {"enabled": feature_enabled(name), "setting": env,
                                 "value": feature_setting(name)} for name, env in FEATURE_FLAGS.items()},
        "host_capabilities": dict.fromkeys(("speech", "notifications", "live_turns", "barge_in"), "not_probed"),
        "timestamp_policy": {"engine_clock": "system clock", "native_history": "unclassified",
                             "explicit_input": ["reported", "estimated", "unknown", "unclassified"]},
        "provenance": {"status": "executable", "task_and_time_probe": "version_command",
                       "skill": "not_probed", "inference": "outside_engine"},
    }


def time_intervals():
    return json.loads(subprocess.check_output(["timew", "export", ":all"], text=True))


def daily_report(db, day):
    now = datetime.now(timezone.utc)
    selected = date.fromisoformat(day) if day is not None else now.date()
    start = datetime.combine(selected, datetime.min.time(), tzinfo=timezone.utc)
    end = start + timedelta(days=1)
    intervals = []
    closed = []
    for raw in time_intervals():
        beginning = moment(raw["start"])
        finish = moment(raw["end"]) if raw.get("end") else None
        if beginning >= end or (finish is not None and finish <= start):
            continue
        if finish is not None and beginning < finish:
            closed.append((max(beginning, start), min(finish, end)))
        intervals.append({"start": beginning.isoformat(), "end": finish.isoformat() if finish else None,
                          "start_source": "unclassified", "end_source": "unclassified" if finish else "unknown",
                          "source": "timewarrior", "tags": raw.get("tags", [])})

    seconds = 0
    covered_until = start
    for beginning, finish in sorted(closed):
        seconds += max(0, (finish - max(covered_until, beginning)).total_seconds())
        covered_until = max(finish, covered_until)

    rows = [row | {"coordination": get(db, "task", row["uuid"])} for row in export_tasks()]
    active = export_tasks("+ACTIVE")
    active_ids = {row["uuid"] for row in active}
    ready = {row["uuid"] for row in export_tasks("+READY")} - active_ids
    blocked = {row["uuid"] for row in export_tasks("+BLOCKED")}
    tasks = {kind: [] for kind in ("ready", "blocked", "deferred", "completed")}
    for row in rows:
        meta = row["coordination"]
        if row["status"] == "completed":
            completed_at = row.get("end")
            if completed_at and start <= moment(completed_at) < end:
                tasks["completed"].append(row)
        elif row["status"] in {"pending", "waiting"}:
            if (meta.get("condition_state") in {"unresolved", "declined"} or row["status"] == "waiting"
                    or (row.get("wait") and moment(row["wait"]) > now)):
                tasks["deferred"].append(row)
            elif row["uuid"] in blocked:
                tasks["blocked"].append(row)
            elif (row["uuid"] in ready and meta.get("ownership") != "other"
                  and meta.get("delegation") not in {"pending", "accepted", "completed"}):
                tasks["ready"].append(row)
    priority_order = {"H": 0, "M": 1, "L": 2}
    tasks["ready"].sort(key=lambda row: (priority_order.get(row.get("priority"), 3),
                                         row.get("due", "~"), row["uuid"]))
    passive = []
    for row in records(db, "activity"):
        beginning = moment(row["start"]) if row.get("start") else None
        finish = moment(row["end"]) if row.get("end") else None
        if (beginning is None or beginning < end) and (finish is None or finish > start):
            passive.append({"start_source": "unclassified" if beginning else "unknown",
                            "end_source": "unclassified" if finish else "unknown"} | row)
    return {
        "schema_version": 1, "version": VERSION, "execution_tier": "executable",
        "window": {"start": start.isoformat(), "end_exclusive": end.isoformat(), "timezone": "UTC"},
        "current_activity": {"tasks": active,
                             "open_intervals": [item for item in intervals if item["end"] is None]},
        "tasks": tasks, "passive_activities": passive, "independent_work": records(db, "work"),
        "personal_time": {"closed_seconds": int(seconds), "intervals": intervals,
                          "calculation": "union_of_closed_timewarrior_intervals_clipped_to_window"},
        "untracked_intervals": None,
        "provenance": {"tasks": "taskwarrior", "personal_time": "timewarrior",
                       "activities_and_progress": "sqlite", "calculations": "cronicle_executable",
                       "task_readiness": "current_snapshot",
                       "untracked_intervals": "unknown_without_an_explicit_coverage_window"},
    }


def render_daily(report):
    print(f"Cronicle {report['window']['start'][:10]} UTC · executable")
    titles = lambda rows: ", ".join(" ".join(row["description"].split()) for row in rows) or "none"
    print("Current:", titles(report["current_activity"]["tasks"]))
    for kind, rows in report["tasks"].items():
        print(f"{kind.capitalize()}:", titles(rows))
    seconds = report["personal_time"]["closed_seconds"]
    hours, seconds = divmod(seconds, 3600)
    minutes, seconds = divmod(seconds, 60)
    print(f"Closed recorded time: {hours:d}:{minutes:02d}:{seconds:02d}")
    print(f"Open intervals: {len(report['current_activity']['open_intervals'])}")
    print(f"Separate activity records: {len(report['passive_activities'])}")
    for row in report["independent_work"]:
        print(f"{row['title']}: {row['completed']}/{row['total']} complete")
    print("Timewarrior boundary origin: unclassified. Untracked time: unknown.")


def report(db, args):
    kind = args.kind
    if kind == "daily":
        return daily_report(db, args.day)
    if kind == "work":
        return records(db, "work")
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
        return time_intervals()
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
                 "observe": observe, "observation": edit_observation, "activity": activity, "reminder": reminder, "work": work}
    for command in mutations:
        commands.add_parser(command).add_argument("json")
    commands.add_parser("status")
    reports = commands.add_parser("report")
    reports.add_argument("kind", choices="all team personal conditional delegated unassigned upcoming overdue completed deferred activity time improvements unresolved reminders daily work".split())
    reports.add_argument("--release")
    reports.add_argument("--format", choices=["json", "text"], default="json")
    reports.add_argument("--day", help="UTC date for report daily (YYYY-MM-DD)")
    reports.add_argument("--task")
    reports.add_argument("--active", action="store_true")
    reports.add_argument("--reconcile", action="store_true")
    output = commands.add_parser("handoff")
    output.add_argument("--format", choices=["markdown"], default="markdown")
    output.add_argument("--release")
    args = parser.parse_args()
    path = Path(os.environ.get("CRONICLE_DATA", Path.home())) / ".cronicle.sqlite3"
    if args.command == "status":
        print(json.dumps(executable_status(path)))
        return
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
            require(args.kind == "daily" or (args.day is None and args.format == "json"),
                    "--day and text rendering are available for report daily.")
            result = report(db, args)
            if args.format == "text":
                render_daily(result)
            else:
                print(json.dumps(result))
        else:
            handoff(db, args.release)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, AttributeError, OSError, sqlite3.Error, subprocess.CalledProcessError) as exc:
        print(f"Cronicle: {getattr(exc, 'stderr', None) or exc}", file=sys.stderr)
        sys.exit(1)
