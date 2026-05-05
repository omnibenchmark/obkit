# plot — annotated profile plots overlaying logger phase ranges on
# denet sample traces. ggplot2 is in Suggests; calls are gated.
#
# Adapted from helpers by Mark Robinson:
# https://github.com/scrna-bench/pipelines-analysis/blob/8bd21d3/analysis/denet-profiling-helpers.R

# Okabe-Ito categorical palette (colorblind-safe).
.cols <- c(
  "#E69F00", "#56B4E9", "#009E73", "#F0E442",
  "#0072B2", "#D55E00", "#CC79A7", "#000000"
)

# Light pastel companion palette for phase rectangles.
.light9 <- c(
  "#DCEAF7", "#FBE5D6", "#E2F0D9", "#FFF2CC", "#EADCF8",
  "#F4CCCC", "#D9EAD3", "#D0E0E3", "#FCE5CD"
)

#' Plot a denet profile with logger phase rectangles overlaid.
#'
#' Renders CPU usage and RSS memory from `samples` as a dual-axis time
#' series, with translucent rectangles spanning each phase range from
#' `ranges`. Times are normalized to start at zero.
#'
#' @param samples Data.frame from `read_aggregates()`. Must contain
#'   `aggregated.ts_ms`, `aggregated.cpu_usage`, `aggregated.mem_rss_kb`.
#' @param ranges Data.frame from `read_phase_ranges()` with `event`,
#'   `xmin`, `xmax` (ms since epoch).
#' @param title Plot title.
#' @param mx Upper limit of the CPU (left) axis, in percent.
#' @param suppress.right,suppress.left Hide the corresponding axis labels;
#'   useful when faceting plots side by side.
#' @return A ggplot object.
#' @export
plot_annotated_profiles <- function(samples, ranges, title = "",
                                    mx = 900,
                                    suppress.right = FALSE,
                                    suppress.left  = FALSE) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("plot_annotated_profiles() requires the 'ggplot2' package; ",
         "install it with install.packages(\"ggplot2\").")
  }

  ts_s <- samples[["aggregated.ts_ms"]] / 1000
  min_time <- min(ts_s)
  mx_memory <- max(samples[["aggregated.mem_rss_kb"]] / 1024)

  ranges <- ranges[!is.na(ranges$xmin) & !is.na(ranges$xmax), , drop = FALSE]
  if (nrow(ranges)) {
    ranges$xmin <- ranges$xmin / 1000
    ranges$xmax <- ranges$xmax / 1000
    spacing <- mx / 10
    ranges$y <- seq(0.9 * mx,
                    0.9 * mx - spacing * (nrow(ranges) - 1),
                    by = -spacing)
    fills <- rep_len(.light9, nrow(ranges))
  }

  p <- ggplot2::ggplot(samples,
                       ggplot2::aes(x = .data[["aggregated.ts_ms"]] / 1000 - min_time,
                                    y = .data[["aggregated.cpu_usage"]]))
  if (nrow(ranges)) {
    p <- p + ggplot2::geom_rect(
      data = ranges,
      mapping = ggplot2::aes(xmin = xmin - min_time, xmax = xmax - min_time,
                             ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE,
      fill = fills,
      alpha = 0.7
    )
  }
  p <- p +
    ggplot2::geom_point() +
    ggplot2::geom_line() +
    ggplot2::geom_line(
      ggplot2::aes(y = .data[["aggregated.mem_rss_kb"]] / 1024 / mx_memory * mx),
      color = "#009E73"
    ) +
    ggplot2::scale_y_continuous(
      name = "cpu usage (%)",
      sec.axis = ggplot2::sec_axis(~ . * mx_memory / mx, name = "memory (MB)"),
      limits = c(0, mx)
    ) +
    ggplot2::geom_hline(yintercept = c(100, 400, 800),
                        colour = c("blue", "orange", "grey")) +
    ggplot2::ggtitle(title) +
    ggplot2::xlab("time (s)") +
    ggplot2::theme_bw()

  if (nrow(ranges)) {
    p <- p + ggplot2::geom_label(
      data = ranges,
      mapping = ggplot2::aes(x = xmin - min_time, y = y, label = event),
      inherit.aes = FALSE, hjust = 0, size = 2
    )
  }

  if (suppress.right) {
    p <- p + ggplot2::theme(
      axis.text.y.right  = ggplot2::element_text(color = "#009E73"),
      axis.title.y.right = ggplot2::element_blank()
    )
  } else {
    p <- p + ggplot2::theme(
      axis.title.y.right = ggplot2::element_text(color = "#009E73")
    )
  }
  if (suppress.left) {
    p <- p + ggplot2::theme(
      axis.text.y.left  = ggplot2::element_blank(),
      axis.title.y.left = ggplot2::element_blank()
    )
  }
  p
}
