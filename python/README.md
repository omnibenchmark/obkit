# obkit

Utility toolkit for [omnibenchmark](https://omnibenchmark.org) modules and
Snakemake workflows. Pure stdlib, zero runtime dependencies.

The R implementation lives in the same repository under `r/obkit`.

## Install

```bash
pip install obkit
```

## Modules

| module        | purpose |
|---------------|---------|
| `obkit.logger` | Structured JSONL lifecycle event logging — drop phase-boundary anchors into a log file so downstream tooling can attribute profiler samples to named phases of a rule. |
| `obkit.prof`   | Parse and align profiler output (denet, Snakemake bench files) with logger events for per-phase resource attribution. *(in progress)* |

## Usage

```python
from obkit.logger import init_logger, emit

init_logger("/path/to/logdir")
emit("align", "start")
# ... do work ...
emit("align", "end", attrs={"reads": 12345})
```

Events are written to `obkit-events.jsonl` inside the directory passed to
`init_logger`. See the [wire format spec](https://github.com/omnibenchmark/obkit/blob/main/docs/spec-logger.md)
for the record schema.

## Status

v0.1, pre-release. Wire format is stable; API may still shift.

## License

MIT — see [LICENSE](LICENSE).
