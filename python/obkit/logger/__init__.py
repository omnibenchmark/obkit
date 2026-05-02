import json
import os
import socket
import sys
from datetime import datetime, timezone

_state = {
    "log_file": None,
    "warned_uninit": False,
}


def init_logger(path):
    if not isinstance(path, str) or not path:
        raise ValueError("init_logger(): 'path' must be a non-empty string")
    os.makedirs(path, exist_ok=True)
    log_file = os.path.join(os.path.realpath(path), "omnibench-events.jsonl")
    _state["log_file"] = log_file
    _state["warned_uninit"] = False
    return log_file


def _iso_ts():
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z"


def emit(event, phase, attrs=None):
    if not isinstance(event, str) or not event:
        raise ValueError("emit(): 'event' must be a non-empty string")
    if phase not in ("start", "end"):
        raise ValueError('emit(): \'phase\' must be "start" or "end"')

    log_file = _state["log_file"]
    if log_file is None:
        if not _state["warned_uninit"]:
            print(
                "obkit: emit() called before init_logger(); events discarded.",
                file=sys.stderr,
            )
            _state["warned_uninit"] = True
        return False

    rec = {
        "ts": _iso_ts(),
        "event": event,
        "phase": phase,
        "pid": os.getpid(),
        "host": socket.gethostname(),
    }
    if attrs is not None:
        if not isinstance(attrs, dict):
            raise ValueError("emit(): 'attrs' must be a dict")
        rec["attrs"] = attrs

    try:
        line = json.dumps(rec, separators=(",", ":"))
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(line + "\n")
        return True
    except Exception as e:
        print(f"obkit: emit() write failed: {e}", file=sys.stderr)
        return False
