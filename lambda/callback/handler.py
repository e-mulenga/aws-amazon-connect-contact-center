"""Called by the inbound contact flow when the centre is closed or the queue is full. Stores a callback request.

The number is kept only until the agent has called back: the row has a short TTL (CALLBACK_RETENTION_DAYS). Numbers that
are hidden or not in E.164 form are rejected and the caller is told the request could not be noted.
"""
import os
import re
import time
import uuid
from datetime import datetime, timezone

import boto3

import emf

_cache = {}
E164 = re.compile(r"^\+[1-9][0-9]{6,14}$")


def _table(env_name):
    key = f"table:{env_name}"
    if key not in _cache:
        _cache[key] = boto3.resource("dynamodb").Table(os.environ[env_name])
    return _cache[key]


def _number(event):
    details = event.get("Details") or {}
    data = details.get("ContactData") or {}
    params = details.get("Parameters") or {}
    chosen = (params.get("callback_number") or (data.get("CustomerEndpoint") or {}).get("Address") or "").strip()
    return chosen, data, params


def handler(event, context):
    number, data, params = _number(event)
    metric = "CallbacksQueued"
    result = {"callback_status": "queued"}
    if not E164.match(number):
        metric = "CallbacksRejected"
        result = {"callback_status": "rejected"}
    else:
        now = datetime.now(timezone.utc)
        retention = int(os.environ.get("CALLBACK_RETENTION_DAYS", "7"))
        callback_id = uuid.uuid4().hex
        _table("CALLBACKS_TABLE").put_item(
            Item={
                "callback_id": callback_id,
                "phone_number": number,
                "contact_id": data.get("ContactId", ""),
                "reason": str(params.get("reason", "after_hours"))[:40],
                "created_at": now.isoformat(),
                "status": "queued",
                "expires_at": int(time.time()) + retention * 86400,
            }
        )
        result["callback_id"] = callback_id

    emf.emit(os.environ.get("METRICS_NAMESPACE", "ContactCenter"), {metric: (1, "Count")}, {"Service": "callback"})
    return result
