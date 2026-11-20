"""Test doubles. The handlers cache their AWS clients in a module level dict, so tests replace entries in it."""
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
for sub in ("lambda/shared", "lambda/crm_lookup", "lambda/callback"):
    sys.path.insert(0, os.path.join(ROOT, sub))


class FakeTable:
    def __init__(self, items=None, fail=False):
        self.items = items or {}
        self.puts = []
        self.fail = fail

    def get_item(self, Key):
        if self.fail:
            raise RuntimeError("boom")
        item = self.items.get(next(iter(Key.values())))
        return {"Item": item} if item else {}

    def put_item(self, Item):
        if self.fail:
            raise RuntimeError("boom")
        self.puts.append(Item)
