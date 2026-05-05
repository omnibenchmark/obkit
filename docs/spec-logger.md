# obkit-events spec

`spec: 0.1`

A minimal wire format for streaming structured lifecycle events from
workflow rules (Snakemake and similar). Implementations in any language
that conform to this document produce mutually-readable logs.

## Intended use: coordinated logging with an external profiler

This spec is designed to sit **next to** a sampling profiler like
[denet](https://github.com/btraven00/denet) (or any tool that records
CPU / RSS / IO at a fixed cadence), not to replace it. The profiler
provides the dense time-series; this log provides the sparse,
human-meaningful *anchors* (`align start`, `align end`,
`sort start`, `sort end`, …). At analysis time the two streams are
joined on timestamp so profiler samples can be attributed to named
phases of the rule.

Because the anchors are what get joined, implementations MUST emit
accurate wall-clock timestamps (see `ts` below) and SHOULD include
`pid` so a per-process profiler trace can be matched to the right
event stream.

The keywords MUST, SHOULD, and MAY follow RFC 2119.

## File format

- One JSON object per line (JSONL), UTF-8 encoded, `\n`-terminated.
- Append-only. Implementations MUST open the file in append mode for
  each write (or hold an append-mode handle) so that multiple short
  processes can add events to the same file sequentially.
- Readers MUST tolerate a trailing partial line (a writer killed
  mid-write) by discarding it.
- File path: `<log_dir>/obkit-events.jsonl`, where `<log_dir>` is
  the directory configured by the host application (e.g. via an
  `init_logger(path)` call).

Concurrent writers from multiple processes to the same file are out of
scope for v0.1. Hosts that need parallelism SHOULD give each process
its own `<log_dir>`.

## Event record

### Required fields

| field   | type   | notes                                             |
|---------|--------|---------------------------------------------------|
| `ts`    | string | ISO-8601 UTC, millisecond precision, `Z` suffix.  |
|         |        | Example: `2026-04-20T17:10:00.123Z`.              |
| `event` | string | Caller-supplied name. No schema; opaque to lib.   |
| `phase` | string | One of `"start"` or `"end"`.                      |

### Optional fields

| field   | type    | notes                                            |
|---------|---------|--------------------------------------------------|
| `attrs` | object  | Arbitrary caller key/values. Scalars preferred;  |
|         |         | nested objects allowed but discouraged.          |
| `pid`   | integer | Process id. Implementations SHOULD include it.   |
| `host`  | string  | Hostname. Implementations SHOULD include it.     |

No other top-level fields are defined in v0.1. Implementations MAY add
fields prefixed with `x_` for experimentation; readers MUST ignore
unknown fields.

## Pairing semantics

The library does not auto-pair starts and ends. Consumers pair by
`(pid, event)` in file order. Callers are responsible for emitting a
matching `end` for every `start` they emit. This keeps implementations
trivial and stateless.

## Error handling

`emit()` MUST NOT raise an exception that interrupts the caller's
workflow rule because of I/O problems (missing dir, disk full, etc.).
Implementations SHOULD log a single warning to stderr and continue as
a no-op. Programmer errors (invalid `phase`, missing `event`) MAY
throw.

## Versioning

The spec version at the top of this file (`spec: 0.1`) is the source
of truth. v0 events do NOT carry a version field; bumps to the wire
format will introduce one.
