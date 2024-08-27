# Non-model baseline method for comparison.
# Based off of Aaron's work in cfa-respnet-nowcasting,
# stratified by day-of-week.

baseline <- function(
    obs,
    max_delay = 28,
    quantiles = c(0.05, 0.2, 0.5, 0.8, 0.95)) {
  required_cols <- c("reference_date", "report_date", "confirm", "max_confirm")
  if (!all(required_cols %in% colnames(obs))) {
    cli::cli_abort(
      paste0(
        "The following columns are required: ",
        "{toString(required_cols[!required_cols %in% colnames(obs)])} ",
        "but are not present among ",
        "{toString(colnames(obs))}"
      )
    )
  }

  obs <- obs |>
    filter(.observed)
  obs$day_of_week <- lubridate::wday(obs$reference_date)
  obs_by_day <- split(obs, obs$day_of_week)
  ncst_by_day <- lapply(obs_by_day, baseline_wday, max_delay, quantiles)

  nowcast <- dplyr::bind_rows(ncst_by_day) |>
    arrange(reference_date)

  return(nowcast)
}

baseline_wday <- function(obs, max_delay, quantiles) {
  latest_report_date <- max(obs |> dplyr::pull(report_date))
  train <- obs |>
    dplyr::mutate(lag = report_date - reference_date) |>
    dplyr::filter(
      lag < max_delay,
      reference_date + max_delay < latest_report_date,
      confirm > 0
    )
  train_multipliers <- train |>
    dplyr::group_by(lag) |>
    dplyr::reframe(tibble::enframe(
      quantile(max_confirm / confirm, quantiles), "quantile", "multiplier"
    )) |>
    dplyr::mutate(quantile = as.numeric(sub("%", "", quantile)) / 100)

  nowcast <- obs |>
    dplyr::filter(
      reference_date > latest_report_date - max_delay,
      reference_date <= latest_report_date
    ) |>
    dplyr::mutate(lag = report_date - reference_date) |>
    dplyr::inner_join(train_multipliers, by = dplyr::join_by(lag)) |>
    dplyr::mutate(value = floor(confirm * multiplier)) |>
    dplyr::select(-multiplier, -max_confirm, -lag)

  return(nowcast)
}

