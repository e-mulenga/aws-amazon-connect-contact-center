"""CloudWatch Embedded Metric Format: metrics are written as a structured log line, no API call needed."""
import json
import time
from typing import Dict, Optional, Tuple


def emit(namespace: str, metrics: Dict[str, Tuple[float, str]], dimensions: Optional[Dict[str, str]] = None) -> None:
    dims = dimensions or {}
    payload = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": namespace,
                    "Dimensions": [list(dims)] if dims else [[]],
                    "Metrics": [{"Name": name, "Unit": unit} for name, (_, unit) in metrics.items()],
                }
            ],
        },
        **dims,
        **{name: value for name, (value, _) in metrics.items()},
    }
    print(json.dumps(payload))
