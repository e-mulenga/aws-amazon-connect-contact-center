import importlib.util
import os
import unittest

from helpers import ROOT, FakeTable

spec = importlib.util.spec_from_file_location("callback_handler", os.path.join(ROOT, "lambda", "callback", "handler.py"))
cb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cb)


def event(number="+27821234567", params=None):
    return {"Details": {"ContactData": {"ContactId": "c-9", "CustomerEndpoint": {"Address": number}}, "Parameters": params or {}}}


class CallbackTests(unittest.TestCase):
    def setUp(self):
        os.environ.update({"CALLBACKS_TABLE": "cb", "CALLBACK_RETENTION_DAYS": "7"})
        self.table = FakeTable()
        cb._cache.clear()
        cb._cache["table:CALLBACKS_TABLE"] = self.table

    def test_valid_number_is_queued_with_ttl(self):
        out = cb.handler(event(), None)
        self.assertEqual(out["callback_status"], "queued")
        row = self.table.puts[0]
        self.assertEqual(row["callback_id"], out["callback_id"])
        self.assertGreater(row["expires_at"], 0)

    def test_hidden_number_is_rejected_and_nothing_stored(self):
        out = cb.handler(event("anonymous"), None)
        self.assertEqual(out, {"callback_status": "rejected"})
        self.assertEqual(self.table.puts, [])

    def test_number_from_parameters_wins(self):
        cb.handler(event("anonymous", {"callback_number": "+27831112222"}), None)
        self.assertEqual(self.table.puts[0]["phone_number"], "+27831112222")

    def test_reason_is_truncated(self):
        cb.handler(event(params={"reason": "x" * 100}), None)
        self.assertEqual(len(self.table.puts[0]["reason"]), 40)

    def test_malformed_number_is_rejected(self):
        for bad in ("0821234567", "+0123456", "+27 82 123", ""):
            self.assertEqual(cb.handler(event(bad), None)["callback_status"], "rejected", bad)


if __name__ == "__main__":
    unittest.main()
