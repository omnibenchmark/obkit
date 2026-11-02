# Trimmed from a real denet 0.10.3 trace: metadata header, `tree` samples
# interleaved with `child` and `exit` records that carry no `aggregated`, a
# sample missing `perf`, and a truncated last line.
denet_0103 <- c(
  '{"kind":"metadata","pid":459,"cmd":["Rscript"],"t0_ms":1793612398233}',
  '{"kind":"tree","ts_ms":1000,"parent":{"mem_rss_kb":3776},"children":[],"aggregated":{"ts_ms":1000,"cpu_usage":0.0,"mem_rss_kb":18076,"psi_mem":{"some_avg10":0.0},"perf":{"cycles":0}}}',
  '{"kind":"child","ts_ms":1001,"pid":460,"ppid":459,"cmd":["R"],"exe":"/usr/bin/R"}',
  '{"kind":"tree","ts_ms":1050,"parent":{"mem_rss_kb":3776},"children":[],"aggregated":{"ts_ms":1050,"cpu_usage":95.5,"mem_rss_kb":458000,"psi_mem":{"some_avg10":0.1}}}',
  '{"kind":"exit","ts_ms":1100,"last_sample_to_exit_ms":20}',
  '{"kind":"tree","ts_ms":11'
)

test_that("read_aggregates skips denet 0.10 child/exit records", {
  f <- tempfile(fileext = ".ndjson")
  on.exit(unlink(f), add = TRUE)
  writeLines(denet_0103, f)

  a <- read_aggregates(f)
  expect_equal(nrow(a), 2L)
  expect_equal(a[["aggregated.ts_ms"]], c(1000, 1050))
  expect_equal(a[["aggregated.mem_rss_kb"]], c(18076, 458000))
  expect_equal(a[["aggregated.psi_mem.some_avg10"]], c(0.0, 0.1))
  expect_equal(a[["aggregated.perf.cycles"]], c(0, NA))
})

test_that("read_aggregates output joins with read_phase_ranges", {
  f <- tempfile(fileext = ".ndjson")
  on.exit(unlink(f), add = TRUE)
  writeLines(denet_0103, f)
  a <- read_aggregates(f)
  p <- data.frame(event = "read", pid = 1L, xmin = 1040, xmax = 1060)
  s <- a[a[["aggregated.ts_ms"]] >= p$xmin & a[["aggregated.ts_ms"]] <= p$xmax, ]
  expect_equal(max(s[["aggregated.mem_rss_kb"]]), 458000)
})

test_that("read_aggregates returns an empty data.frame with no samples", {
  f <- tempfile(fileext = ".ndjson")
  on.exit(unlink(f), add = TRUE)
  writeLines(denet_0103[c(1, 5)], f)
  expect_equal(nrow(read_aggregates(f)), 0L)
})
