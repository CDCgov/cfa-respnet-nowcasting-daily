# Wrapper function for nowcast CRPS
# This is a duplicate but I was struggling with enw_score_nowcast()

crps_nowcast <- function(nowcast, latest_obs) {
  true_values <- latest_obs |>
    dplyr::select(c("reference_date", "confirm"))
  samples <- epinowcast::enw_nowcast_samples(nowcast$fit[[1]],
                                             nowcast$latest[[1]])
  samples_long <- samples |>
    dplyr::select(c("reference_date", "sample", ".draw"))
  samples_wide <- samples_long |>
    tidyr::pivot_wider(names_from = ".draw", values_from = "sample")
  # check that reference date columns match
  stopifnot(true_values$reference_date == samples_wide$reference_date)
  # then can remove reference dates
  true_values <- true_values$confirm
  samples_wide <- samples_wide |> dplyr::select(-"reference_date")
  return(scoringutils::crps_sample(true_values, as.matrix(samples_wide)))
}
