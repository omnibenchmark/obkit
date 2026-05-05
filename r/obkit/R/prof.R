# prof — parse and align profiling outputs (denet, Snakemake bench files)
# with logger events for per-phase resource attribution.
#
# Adapted from helpers by Mark Robinson:
# https://github.com/scrna-bench/pipelines-analysis/blob/8bd21d3/analysis/denet-profiling-helpers.R

#' Parse aggregated samples from a denet JSONL trace.
#'
#' Reads a denet output file where each non-header line is a JSON object
#' containing an `aggregated` field, and returns a data.frame of those
#' samples with columns prefixed `aggregated.` (e.g. `aggregated.ts_ms`,
#' `aggregated.cpu_usage`, `aggregated.mem_rss_kb`).
#'
#' The first line is treated as a metadata header and skipped, matching
#' denet's current output format.
#'
#' @param path Path to a denet JSONL file.
#' @return A data.frame, one row per sample.
#' @export
read_aggregates <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (length(lines) <= 1L) {
    return(data.frame())
  }
  rows <- lapply(lines[-1L], function(ln) {
    rec <- jsonlite::fromJSON(ln, simplifyVector = FALSE)
    as.data.frame(rec[["aggregated"]], stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

.parse_iso_ms <- function(ts) {
  # ISO-8601 with millisecond precision and trailing Z, per SPEC.md.
  base <- as.POSIXct(sub("\\.\\d+Z$", "Z", ts),
                     format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ms <- as.integer(sub(".*\\.(\\d+)Z$", "\\1", ts))
  as.numeric(base) * 1000 + ms
}

#' Read phase ranges from an obkit logger event file.
#'
#' Reads the JSONL file written by `logger_emit()` and pairs `start`/`end`
#' events on `(pid, event)` in file order, per SPEC.md v0.1. Returns one
#' row per completed pair; unmatched starts and ends are dropped with a
#' warning.
#'
#' Timestamps are returned as milliseconds since the Unix epoch so they
#' can be aligned with `read_aggregates()` (`aggregated.ts_ms`).
#'
#' @param path Path to the events JSONL file.
#' @return A data.frame with columns `event`, `pid`, `xmin`, `xmax`.
#'   `xmin` and `xmax` are numeric ms-since-epoch.
#' @export
read_phase_ranges <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (!length(lines)) {
    return(data.frame(event = character(), pid = integer(),
                      xmin = numeric(), xmax = numeric()))
  }
  recs <- lapply(lines, function(ln) {
    tryCatch(jsonlite::fromJSON(ln, simplifyVector = FALSE),
             error = function(e) NULL)
  })
  recs <- Filter(Negate(is.null), recs)

  open <- list()  # key "<pid>|<event>" -> xmin (ms)
  out_event <- character()
  out_pid   <- integer()
  out_min   <- numeric()
  out_max   <- numeric()
  for (r in recs) {
    if (is.null(r$event) || is.null(r$phase) || is.null(r$ts)) next
    pid <- if (is.null(r$pid)) NA_integer_ else as.integer(r$pid)
    key <- paste0(pid, "|", r$event)
    ts_ms <- .parse_iso_ms(r$ts)
    if (identical(r$phase, "start")) {
      open[[key]] <- ts_ms
    } else if (identical(r$phase, "end")) {
      if (is.null(open[[key]])) {
        warning(sprintf("read_phase_ranges(): unmatched end for event=%s pid=%s",
                        r$event, pid))
        next
      }
      out_event <- c(out_event, r$event)
      out_pid   <- c(out_pid, pid)
      out_min   <- c(out_min, open[[key]])
      out_max   <- c(out_max, ts_ms)
      open[[key]] <- NULL
    }
  }
  if (length(open)) {
    warning(sprintf("read_phase_ranges(): %d unmatched start event(s)",
                    length(open)))
  }
  data.frame(event = out_event, pid = out_pid,
             xmin = out_min, xmax = out_max,
             stringsAsFactors = FALSE)
}
