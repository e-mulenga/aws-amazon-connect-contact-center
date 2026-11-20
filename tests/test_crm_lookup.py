import hashlib
import hmac
import importlib.util
import os
import unittest

from helpers import ROOT, FakeTable

spec = importlib.util.spec_from_file_location("crm_lookup_handler", os.path.join(ROOT, "lambda", "crm_lookup", "handler.py"))
crm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(crm)

SECRET = b"test-secret"


def event(number="+27821234567"):
    return {"Details": {"ContactData": {"ContactId": "c-1", "Channel": "VOICE", "CustomerEndpoint": {"Address": number}}}}


class CrmLookupTests(unittest.TestCase):
    def setUp(self):
        os.environ.update({"CUSTOMERS_TABLE": "c", "INTERACTIONS_TABLE": "i", "INTERACTION_RETENTION_DAYS": "30"})
        key = hmac.new(SECRET, b"+27821234567", hashlib.sha256).hexdigest()
        self.customers = FakeTable({key: {"customer_key": key, "tier": "priority", "language": "en", "segment": "business"}})
        self.interactions = FakeTable()
        crm._cache.clear()
        crm._cache.update({"secret": SECRET, "table:CUSTOMERS_TABLE": self.customers, "table:INTERACTIONS_TABLE": self.interactions})

    def test_known_customer_gets_tier(self):
        out = crm.handler(event(), None)
        self.assertEqual(out["customer_found"], "true")
        self.assertEqual(out["customer_tier"], "priority")
        self.assertEqual(out["customer_segment"], "business")

    def test_unknown_customer_is_standard(self):
        out = crm.handler(event("+27829999999"), None)
        self.assertEqual(out, {"customer_found": "false", "customer_tier": "standard", "customer_language": "en", "customer_segment": "general"})

    def test_hidden_number_is_standard_and_not_looked_up(self):
        out = crm.handler(event("anonymous"), None)
        self.assertEqual(out["customer_tier"], "standard")

    def test_unknown_tier_value_falls_back_to_standard(self):
        key = hmac.new(SECRET, b"+27820000000", hashlib.sha256).hexdigest()
        self.customers.items[key] = {"customer_key": key, "tier": "platinum"}
        self.assertEqual(crm.handler(event("+27820000000"), None)["customer_tier"], "standard")

    def test_lookup_failure_fails_open(self):
        crm._cache["table:CUSTOMERS_TABLE"] = FakeTable(fail=True)
        out = crm.handler(event(), None)
        self.assertEqual(out["customer_tier"], "standard")
        self.assertEqual(out["customer_found"], "false")

    def test_interaction_row_has_no_phone_number_and_has_ttl(self):
        crm.handler(event(), None)
        row = self.interactions.puts[0]
        self.assertNotIn("+27821234567", str(row))
        self.assertIn("expires_at", row)

    def test_audit_failure_does_not_break_call(self):
        crm._cache["table:INTERACTIONS_TABLE"] = FakeTable(fail=True)
        self.assertEqual(crm.handler(event(), None)["customer_tier"], "priority")


if __name__ == "__main__":
    unittest.main()
