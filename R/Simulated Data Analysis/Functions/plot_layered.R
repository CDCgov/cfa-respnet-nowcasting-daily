# Note this only works for nowcasts from epinowcast
# that are on the same timescale

plot_layered <- function(nowcasts, labels) {
  library(ggplot2)
  n <- length(nowcasts)
  summaries <- lapply(seq_len(n), function(i) {
    nowcast <- nowcasts[[i]]
    smry <- epinowcast::enw_nowcast_summary(nowcast$fit[[1]],
                                            nowcast$latest[[1]])
    smry <- smry[, c("reference_date", "mean", "median", "q5",
                     "q20", "q80", "q95")]
    smry <- cbind(smry, "Model" = labels[i])
    return(smry)
  }
  )
  summaries <- dplyr::bind_rows(summaries)
  plt <- ggplot(summaries, aes(x = reference_date,
                               group = Model, color = Model, fill = Model)) +
    theme_bw()
  for (i in seq_len(n)) {
    plt <- plt +
      geom_line(mapping = aes(y = mean), linetype = "dashed") +
      geom_line(mapping = aes(y = median)) +
      geom_ribbon(mapping = aes(ymin = q5, ymax = q95),
                  alpha = 0.05, linewidth = 0.2) +
      geom_ribbon(mapping = aes(ymin = q20, ymax = q80, col = NULL),
                  alpha = 0.05)
  }
  return(plt)
}