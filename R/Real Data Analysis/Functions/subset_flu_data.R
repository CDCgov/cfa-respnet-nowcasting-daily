# Function to take incidence CSV for the whole season
# and subset it to only the desired dates + preprocess
# for epinowcast

subset_flu_data <- function(file, end_date, weeks_to_keep,
                            agg_to_week = FALSE, report_day) {
  # add week aggregation later
  file <- read.csv(file) |>
    enw_add_cumulative() |>
    enw_complete_dates() |>
    mutate(day_of_week = lubridate::wday(report_date, label = TRUE)) |>
    enw_filter_report_dates(latest_date = end_date) |>
    enw_filter_reference_dates(include_days = 7 * weeks_to_keep) |>
    mutate(.observed = ifelse(day_of_week == report_day, TRUE, FALSE)) |>
    mutate(not_report_day = ifelse(day_of_week != report_day,
                                   1,
                                   0)) |>
    enw_preprocess_data()
  return(file)
}