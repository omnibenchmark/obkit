import os
import tempfile

import pytest

from obkit.logger import _state, emit, init_logger


def test_init_logger_creates_missing_directory_and_returns_log_path():
    with tempfile.TemporaryDirectory() as base:
        d = os.path.join(base, "new-subdir")
        assert not os.path.exists(d)
        p = init_logger(d)
        assert os.path.isdir(d)
        assert os.path.basename(p) == "obkit-events.jsonl"


def test_init_logger_rejects_bad_input():
    with pytest.raises((ValueError, TypeError)):
        init_logger("")
    with pytest.raises((ValueError, TypeError)):
        init_logger(None)
    with pytest.raises((ValueError, TypeError)):
        init_logger(["a", "b"])


def test_emit_without_init_warns_once_and_noops(capsys):
    _state["log_file"] = None
    _state["warned_uninit"] = False

    result = emit("x", "start")
    captured = capsys.readouterr()
    assert "before init_logger" in captured.err
    assert result is False

    emit("x", "end")
    captured2 = capsys.readouterr()
    assert captured2.err == ""
