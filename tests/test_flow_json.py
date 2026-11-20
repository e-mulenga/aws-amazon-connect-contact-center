"""Static checks on the Terraform that builds the contact flow: every transition target exists and the flow ends."""
import os
import re
import unittest

from helpers import ROOT


class FlowGraphTests(unittest.TestCase):
    def setUp(self):
        self.src = open(os.path.join(ROOT, "modules", "contact-flows", "main.tf")).read()
        self.ids = set(re.findall(r'Identifier\s*=\s*"([a-z_]+)"', self.src))
        self.targets = set(re.findall(r'NextAction\s*=\s*"([a-z_]+)"', self.src))

    def test_every_target_is_an_action(self):
        self.assertEqual(self.targets - self.ids, set())

    def test_every_action_is_reachable_or_the_start(self):
        self.assertEqual(self.ids - self.targets - {"logging"}, set())

    def test_start_action_exists(self):
        start = re.search(r'StartAction\s*=\s*"([a-z_]+)"', self.src).group(1)
        self.assertIn(start, self.ids)

    def test_flow_has_a_disconnect(self):
        self.assertIn("DisconnectParticipant", self.src)


if __name__ == "__main__":
    unittest.main()
