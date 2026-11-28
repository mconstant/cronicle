import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

CLI = Path(os.environ.get("CRONICLE_LEDGER", Path(__file__).resolve().parents[1] / "ledger.py"))


class LedgerTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.env = dict(os.environ, CRONICLE_DATA=self.directory.name, CRONICLE_FEATURE_INDEPENDENT_WORK="on")
        location = Path(self.directory.name)
        (location / "tasks").mkdir()
        (location / "taskrc").write_text(f"data.location={location / 'tasks'}\n")
        time_data = location / "timewarrior"
        time_data.mkdir()
        self.env["TIMEWARRIORDB"] = str(time_data)
        self.env.update(TASKRC=str(location / "taskrc"), TASKDATA=str(location / "tasks"))

    def run_cli(self, *args):
        return subprocess.check_output(["python3", str(CLI), *args], env=self.env, text=True)

    def put(self, command, **data):
        return json.loads(self.run_cli(command, json.dumps(data)))

    def test_independent_work_progress(self):
        directory = Path(os.environ.get("CRONICLE_FIXTURES", Path(__file__).parent / "fixtures"))
        scenario = json.loads((directory / "independent-work.json").read_text())
        baseline = self.put("work", **scenario)
        self.assertEqual(baseline["completed"], 0)
        self.assertEqual(baseline["reached_amount_minor"], 0)
        self.assertEqual(self.put("work", **scenario), baseline)
        key = scenario["id"]
        first = self.put("work", id=key, completed=40)
        self.assertEqual(first["reached_amount_minor"], 10000)
        self.assertEqual(first, self.put("work", id=key, completed=40))
        errors = [
            {"id": key, "completed": 39},
            {"id": key, "completed": 92},
            {"id": key, "research_answer": "A substantive answer"},
            {"id": key, "total": 5},
        ]
        for data in errors:
            with self.assertRaises(subprocess.CalledProcessError):
                self.put("work", **data)
        self.assertEqual(json.loads(self.run_cli("report", "work")), [first])
        correction = self.put("work", id=key, completed=39, correction=True)
        self.assertEqual(correction["reached_amount_minor"], 0)
        final = self.put("work", id=key, completed=91)
        self.assertEqual(final["reached_amount_minor"], 20000)
        self.assertEqual(final["remaining"], 0)
        daily = json.loads(self.run_cli("report", "daily", "--day", "2020-01-02"))
        self.assertEqual(daily["independent_work"], [final])

    def test_feature_flag_is_fail_closed_and_keeps_existing_data(self):
        directory = Path(os.environ.get("CRONICLE_FIXTURES", Path(__file__).parent / "fixtures"))
        scenario = json.loads((directory / "independent-work.json").read_text())
        del self.env["CRONICLE_FEATURE_INDEPENDENT_WORK"]
        with self.assertRaises(subprocess.CalledProcessError):
            self.put("work", **scenario)
        self.assertFalse(json.loads(self.run_cli("status"))["feature_flags"]["independent_work"]["enabled"])
        self.env["CRONICLE_FEATURE_INDEPENDENT_WORK"] = "on"
        baseline = self.put("work", **scenario)
        self.env["CRONICLE_FEATURE_INDEPENDENT_WORK"] = "typo"
        with self.assertRaises(subprocess.CalledProcessError):
            self.put("work", id=scenario["id"], completed=40)
        self.assertEqual(json.loads(self.run_cli("report", "work")), [baseline])

    def test_morning_report_protects_the_active_task_and_shows_blockers(self):
        priority = self.put("task-upsert", title="Prepare breakfast", priority="H")
        blocked = self.put("task-upsert", title="Serve breakfast", depends=[priority["uuid"]])
        future = self.put("task-upsert", title="Call plumber next week", wait="2099-01-01")
        subprocess.run(["task", priority["uuid"], "start"], env=self.env, check=True, capture_output=True)
        before = json.loads(self.run_cli("report", "daily"))
        self.assertEqual([t["uuid"] for t in before["current_activity"]["tasks"]], [priority["uuid"]])
        self.assertEqual([t["uuid"] for t in before["tasks"]["blocked"]], [blocked["uuid"]])
        self.assertEqual([t["uuid"] for t in before["tasks"]["deferred"]], [future["uuid"]])
        self.put("task-upsert", id=priority["uuid"], status="completed")
        after = json.loads(self.run_cli("report", "daily"))
        self.assertEqual([t["uuid"] for t in after["tasks"]["ready"]], [blocked["uuid"]])
        self.assertEqual([t["uuid"] for t in after["tasks"]["completed"]], [priority["uuid"]])

    def test_status_probes_dependencies_and_identifies_storage(self):
        state = json.loads(self.run_cli("status"))
        self.assertEqual(state["execution_tier"], "executable")
        self.assertEqual(state["state"]["coordination"]["location"],
                         str(Path(self.directory.name) / ".cronicle.sqlite3"))
        self.assertTrue(state["components"]["taskwarrior"]["available"])
        self.assertTrue(state["components"]["timewarrior"]["available"])
        self.assertEqual(state["host_capabilities"]["speech"], "not_probed")

    def test_daily_clips_intervals_and_keeps_estimates_separate(self):
        config = Path(self.directory.name) / "time"
        config.mkdir()
        self.env["TIMEWARRIORDB"] = str(config)
        subprocess.run(["timew", "track", "2020-01-01T23:30:00Z", "to",
                        "2020-01-02T00:30:00Z", "Synthetic"], env=self.env,
                       check=True, capture_output=True)
        self.put("activity", id="a", title="Dishwasher", kind="elapsed", state="ended",
                 start="2020-01-02T00:00:00+00:00", end="2020-01-02T01:00:00+00:00",
                 start_source="estimated", end_source="reported")
        self.put("activity", id="b", title="Unknown waiting", kind="waiting")
        daily = json.loads(self.run_cli("report", "daily", "--day", "2020-01-02"))
        self.assertEqual(daily["schema_version"], 1)
        self.assertEqual(daily["personal_time"]["closed_seconds"], 1800)
        self.assertEqual(daily["personal_time"]["intervals"][0]["start_source"], "unclassified")
        self.assertEqual(daily["passive_activities"][0]["start_source"], "estimated")
        self.assertEqual(daily["passive_activities"][1]["start_source"], "unknown")
        self.assertIsNone(daily["untracked_intervals"])
        self.assertEqual(daily["window"]["timezone"], "UTC")
        text = self.run_cli("report", "daily", "--day", "2020-01-02", "--format", "text")
        self.assertIn("Closed recorded time: 0:30:00", text)
        self.assertIn("Separate activity records: 2", text)
        self.assertIn("Untracked time: unknown", text)

    def test_observation_lifecycle_and_handoff(self):
        first = self.put("observe", category="bug", source="user", title="Repeated speech", description="An acknowledgment repeated")
        second = self.put("observe", category="bug", source="user", title=" repeated speech ")
        other = self.put("observe", category="bug", source="assistant", title="Repeated speech")
        self.assertEqual(first["id"], second["id"])
        self.assertNotEqual(first["id"], other["id"])
        self.assertEqual(second["frequency"], 2)
        self.assertEqual(second["description"], first["description"])
        self.assertIn("Repeated speech", self.run_cli("handoff", "--format", "markdown"))
        self.assertNotIn("Publish", self.run_cli("handoff"))
        self.assertIn("Publish", self.run_cli("handoff", "--release", "v1.1.0"))
        self.put("observation", id=first["id"], status="resolved", resolved_version="v1.0.0")
        self.assertEqual(len(json.loads(self.run_cli("report", "improvements", "--release", "v1.0.0"))), 1)

    def test_parallel_activity_unknown_times(self):
        a = self.put("activity", id="a", title="Cook", kind="waiting")
        self.put("activity", id="b", title="Cleanup", kind="delegated")
        self.assertIsNone(a["start"])
        self.assertIsNone(a["duration_seconds"])
        self.put("activity", id="a", state="ended")
        self.assertEqual(len(json.loads(self.run_cli("report", "activity"))["parallel"]), 1)

    def test_thanksgiving_coordination(self):
        probes = self.put("task-upsert", title="Retrieve probes", project="Dinner")
        self.assertEqual(probes["uuid"], self.put(
            "task-upsert", title="retrieve probes", project="Dinner")["uuid"])
        gateway = self.put("task-upsert", title="Set up gateway", project="Dinner",
                           due="2026-11-25", depends=[probes["uuid"]])
        delegated = self.put("task-upsert", title="Monitor oven", project="Dinner")
        self.put("task-meta", id=probes["uuid"], ownership="personal")
        self.put("task-meta", id=gateway["uuid"], ownership="personal", condition="Host requests it")
        self.put("task-meta", id=delegated["uuid"], ownership="other", owner="Guest", delegation="accepted")

        def titles(report):
            return {r["description"] for r in json.loads(self.run_cli("report", report))}

        self.assertIn("Retrieve probes", titles("personal"))
        self.assertNotIn("Set up gateway", titles("personal"))
        self.assertNotIn("Set up gateway", titles("overdue"))
        self.assertIn("Monitor oven", titles("delegated"))
        self.assertNotIn("Monitor oven", titles("personal"))
        self.assertIn("Monitor oven", titles("team"))
        self.put("task-meta", id=delegated["uuid"], ownership="unassigned", owner="", delegation="none")
        self.assertIn("Monitor oven", titles("unassigned"))
        self.put("task-upsert", id=probes["uuid"], title="Retrieve both probes", status="completed")
        self.assertIn("Retrieve both probes", titles("completed"))
        self.assertEqual(probes["uuid"], self.put("task-upsert", title="Retrieve both probes",
                         project="Dinner", status="completed")["uuid"])
        self.assertNotIn("Set up gateway", titles("personal"))
        self.put("task-meta", id=gateway["uuid"], condition_state="satisfied")
        self.assertIn("Set up gateway", titles("personal"))
        self.put("task-meta", id=gateway["uuid"], condition="Another explicit request")
        self.assertNotIn("Set up gateway", titles("personal"))
        self.put("task-meta", id=gateway["uuid"], condition_state="declined")
        self.assertNotIn("Set up gateway", titles("personal"))
        self.assertIn("Set up gateway", titles("conditional"))
        self.assertIn("Set up gateway", titles("deferred"))

    def test_reminders_are_receipts_with_stable_identity(self):
        task = self.put("task-upsert", title="Check equipment")["uuid"]
        args = dict(task=task, at="2026-11-27T12:00:00+00:00", message="Check", receipt="host-123")
        a = self.put("reminder", **args)
        self.assertEqual(a, self.put("reminder", **args))
        self.put("task-upsert", id=task, status="completed")
        self.assertEqual([a], json.loads(self.run_cli("report", "reminders", "--reconcile")))
        self.put("reminder", id=a["id"], status="cancelled")
        self.assertEqual(json.loads(self.run_cli("report", "reminders", "--task", task, "--active")), [])


if __name__ == "__main__":
    unittest.main()
