read_events <- function(log_file) {
  lines <- readLines(log_file, warn = FALSE)
  lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)
}

test_that("logger_init creates missing directory and returns log path", {
  d <- file.path(tempdir(), paste0("ob-init-", as.integer(Sys.time())))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_false(dir.exists(d))
  p <- logger_init(d)
  expect_true(dir.exists(d))
  expect_equal(basename(p), "obkit-events.jsonl")
})

test_that("logger_init rejects bad input", {
  expect_error(logger_init(""), "non-empty")
  expect_error(logger_init(NULL), "non-empty")
  expect_error(logger_init(c("a", "b")), "non-empty")
})

test_that("logger_emit without init warns once and no-ops", {
  st <- get(".obkit_state", envir = asNamespace("obkit"))
  st$log_file <- NULL
  st$warned_uninit <- FALSE
  expect_warning(out <- logger_emit("x", "start"), "before logger_init")
  expect_false(out)
  expect_silent(logger_emit("x", "end"))
})

test_that("logger_emit writes required fields in JSONL", {
  d <- file.path(tempdir(), paste0("ob-emit-", as.integer(Sys.time())))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  log_file <- logger_init(d)

  logger_emit("align", "start")
  logger_emit("align", "end", attrs = list(nreads = 12345, ok = TRUE))

  ev <- read_events(log_file)
  expect_length(ev, 2)

  for (e in ev) {
    expect_true(all(c("ts", "event", "phase", "pid", "host") %in% names(e)))
    expect_match(e$ts, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$")
    expect_equal(e$event, "align")
  }
  expect_equal(ev[[1]]$phase, "start")
  expect_equal(ev[[2]]$phase, "end")
  expect_equal(ev[[2]]$attrs$nreads, 12345)
  expect_true(ev[[2]]$attrs$ok)
})

test_that("logger_emit validates phase", {
  d <- file.path(tempdir(), paste0("ob-phase-", as.integer(Sys.time())))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  logger_init(d)
  expect_error(logger_emit("x", "begin"), "start.*end")
  expect_error(logger_emit("", "start"), "non-empty")
})

test_that("logger_emit appends across calls (does not truncate)", {
  d <- file.path(tempdir(), paste0("ob-append-", as.integer(Sys.time())))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  log_file <- logger_init(d)
  for (i in 1:5) logger_emit(paste0("e", i), "start")
  expect_length(readLines(log_file), 5)
})
