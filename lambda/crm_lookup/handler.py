"""Called by the inbound contact flow. Looks the caller up by a keyed hash of the phone number and returns the tier.

The phone number is never logged or stored by this function. The table key is HMAC-SHA256(secret, number), so the
table alone cannot be reversed into phone numbers. The function fails open: if the lookup fails the caller is treated
as a standard customer and the call carries on.
"""
import hashlib
import hmac
import os
import time
import uuid
from datetime import datetime, timezone

import boto3

import emf

_cache = {}
TIERS = {"standard", "priority"}


def _table(env_name):
    key = f"table:{env_name}"
    if key not in _cache:
        _cache[key] = boto3.resource("dynamodb").Table(os.environ[env_name])
    return _cache[key]


def _secret():
    if "secret" not in _cache:
        client = boto3.client("secretsmanager")
        _cache["secret"] = client.get_secret_value(SecretId=os.environ["PSEUDONYMISATION_SECRET_ARN"])["SecretString"].encode()
    return _cache["secret"]


def customer_key(number):
    return hmac.new(_secret(), number.encode(), hashlib.sha256).hexdigest()


def _number(event):
    data = (event.get("Details") or {}).get("ContactData") or {}
    return ((data.get("CustomerEndpoint") or {}).get("Address") or "").strip(), data


def _record(data, tier, found):
    now = datetime.now(timezone.utc)
    retention = int(os.environ.get("INTERACTION_RETENTION_DAYS", "365"))
    _table("INTERACTIONS_TABLE").put_item(
        Item={
            "day": now.strftime("%Y-%m-%d"),
            "ts_id": f"{now.strftime('%H:%M:%S.%f')}#{uuid.uuid4().hex[:8]}",
            "contact_id": data.get("ContactId", ""),
            "channel": data.get("Channel", "VOICE"),
            "tier": tier,
            "customer_found": found,
            "expires_at": int(time.time()) + retention * 86400,
        }
    )


def handler(event, context):
    number, data = _number(event)
    tier, language, segment, found = "standard", "en", "general", False
    outcome = "miss"
    try:
        if number.startswith("+"):
            item = _table("CUSTOMERS_TABLE").get_item(Key={"customer_key": customer_key(number)}).get("Item")
            if item:
                found = True
                outcome = "hit"
                tier = item.get("tier") if item.get("tier") in TIERS else "standard"
                language = str(item.get("language", "en"))
                segment = str(item.get("segment", "general"))
        try:
            _record(data, tier, found)
        except Exception as exc:  # the audit row is best effort, the call must not depend on it
            print(f"interaction record failed: {type(exc).__name__}")
    except Exception as exc:
        outcome = "error"
        tier, found = "standard", False
        print(f"crm lookup failed: {type(exc).__name__}")

    emf.emit(
        os.environ.get("METRICS_NAMESPACE", "ContactCenter"),
        {"CrmLookups": (1, "Count"), f"Crm{outcome.capitalize()}": (1, "Count")},
        {"Service": "crm_lookup"},
    )
    return {
        "customer_found": "true" if found else "false",
        "customer_tier": tier,
        "customer_language": language,
        "customer_segment": segment,
    }
