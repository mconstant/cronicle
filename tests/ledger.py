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
        self.env = dict(os.environ, CRONICLE_DATA=self.directory.name)
        location = Path(self.directory.name)
        (location / "tasks").mkdir()
        (location / "taskrc").write_text(f"data.location={location / 'tasks'}\n")
        self.env.update(TASKRC=str(location / "taskrc"), TASKDATA=str(location / "tasks"))

    def run_cli(self, *args):
        return subprocess.check_output(["python3", str(CLI), *args], env=self.env, text=True)

    def put(self, command, **data):
        return json.loads(self.run_cli(command, json.dumps(data)))

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
