import json
import re
import tempfile

import pytest

from obkit.logger import emit, init_logger


def read_events(log_file):
    with open(log_file) as f:
        return [json.loads(line) for line in f if line.strip()]


def test_emit_writes_required_fields_in_jsonl():
    with tempfile.TemporaryDirectory() as d:
        log_file = init_logger(d)

        emit("align", "start")
        emit("align", "end", attrs={"nreads": 12345, "ok": True})

        events = read_events(log_file)
        assert len(events) == 2

        ts_pattern = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$")
        for e in events:
            assert all(k in e for k in ("ts", "event", "phase", "pid", "host"))
            assert ts_pattern.match(e["ts"])
            assert e["event"] == "align"

        assert events[0]["phase"] == "start"
        assert events[1]["phase"] == "end"
        assert events[1]["attrs"]["nreads"] == 12345
        assert events[1]["attrs"]["ok"] is True


def test_emit_validates_phase():
    with tempfile.TemporaryDirectory() as d:
        init_logger(d)
        with pytest.raises(ValueError, match=r"start.*end"):
            emit("x", "begin")
        with pytest.raises(ValueError, match=r"non-empty"):
            emit("", "start")


def test_emit_appends_across_calls_does_not_truncate():
    with tempfile.TemporaryDirectory() as d:
        log_file = init_logger(d)
        for i in range(5):
            emit(f"e{i}", "start")
        with open(log_file) as f:
            lines = f.readlines()
        assert len(lines) == 5
