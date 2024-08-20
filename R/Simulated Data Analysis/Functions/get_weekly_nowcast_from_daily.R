get_weekly_nowcast_from_daily <- function(nowcast, nowcast_data,
                                          end_of_week,
                                          quantiles = c(0.05, 0.2, 0.5,
                                                        0.8, 0.95),
                                          output) {
  # Pull off the samples
  post_samples <- epinowcast::enw_nowcast_samples(nowcast$fit[[1]],
                                                  nowcast$latest[[1]])
  # If first week is not full, get the data from the missing days
  actual_first_date <- min(post_samples$reference_date)
  desired_first_date <- lubridate::floor_date(min(post_samples$reference_date),
                                              week_start = end_of_week,
                                              unit = "week")
  miss_days <- nowcast_data$obs[[1]] |>
    dplyr::filter(reference_date >= desired_first_date &
                    reference_date < actual_first_date) |>
    dplyr::summarise(sample = max(confirm), .by = reference_date)
  miss_counts <- sum(miss_days$sample)
  # If last week is not full, cut it off
  last_date <- lubridate::floor_date(max(post_samples$reference_date),
                                     week_start = end_of_week,
                                     unit = "week")
  # Convert dates to weeks
  post_samples <- post_samples |>
    dplyr::filter(reference_date < last_date) |>
    dplyr::mutate(ref_wk = lubridate::ceiling_date(reference_date,
                                                   unit = "weeks",
                                                   week_start = end_of_week)) |>
    dplyr::mutate(rep_wk = lubridate::ceiling_date(report_date,
                                                   unit = "weeks",
                                                   week_start = end_of_week)) |>
    # Group by draws and reference + report week
    dplyr::group_by(ref_wk, .draw) |>
    # Then sum
    dplyr::summarise(week_sample = sum(sample)) |>
    # Add the missing counts to the first week (the not-modelled dates)
    dplyr::ungroup() |>
    dplyr::mutate(week_sample = ifelse(ref_wk == min(ref_wk),
                                       week_sample + miss_counts,
                                       week_sample))
  if (match.arg(output, c("summary", "samples")) == "samples") {
    return(post_samples)
  }
  if (match.arg(output, c("summary", "samples")) == "summary") {
    qt <- post_samples |>
      dplyr::group_by(ref_wk) |>
      dplyr::summarise(tibble::as_tibble_row(quantile(week_sample, quantiles)))
    mean <- post_samples |>
      dplyr::group_by(ref_wk) |>
      dplyr::summarise(mean = mean(week_sample)) |>
      dplyr::select(mean)
    return(cbind(qt, mean))
  }
}