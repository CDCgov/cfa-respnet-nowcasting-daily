# Note this function is really not general at all
# and I'm just using it to save myself some pain

plot_layered <- function(nowcasts, labels, latest = NULL, input = "nowcast") {
  library(ggplot2)
  n <- length(nowcasts)
  if (input == "nowcast") {
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
  } else if (input == "summary") {
    summaries <- lapply(seq_len(n), function(i) {
      smry <- nowcasts[[i]]
      colnames(smry) <- c("reference_date", "q5", "q20", "median",
                          "q80", "q95", "mean")
      smry <- cbind(smry, "Model" = labels[i])
    })
  } else {
    stop("invalid input type")
  }
  summaries <- dplyr::bind_rows(summaries)
  plt <- ggplot(summaries, aes(x = reference_date,
                               group = Model)) +
    theme_bw()
  for (i in seq_len(n)) {
    plt <- plt +
      geom_line(mapping = aes(y = mean, color = Model),
                 linetype = "dashed") +
      geom_line(mapping = aes(y = median, color = Model)) +
      geom_ribbon(mapping = aes(ymin = q5, ymax = q95, color = Model,
                                  fill = Model),
                  alpha = 0.1, linewidth = 0.2) +
      geom_ribbon(mapping = aes(ymin = q20, ymax = q80, fill = Model),
                  alpha = 0.1)
  }
  if (!is.null(latest)) {
    latest_obs <- epinowcast:::coerce_dt(latest) |>
      filter(reference_date >= min(summaries$reference_date) &
               reference_date <= max(summaries$reference_date)) |>
      mutate(latest_confirm = confirm)
    latest_obs <- cbind(latest_obs, "Model" = "Latest Observations")
    plt <- plt +
      geom_point(
        data = latest_obs, aes(y = latest_confirm),
        na.rm = TRUE, alpha = 1, size = 1.5, shape = 2,
        color = "black"
      )
  }
  return(plt + xlab("Date") + ylab("Hospital Admissions"))
}