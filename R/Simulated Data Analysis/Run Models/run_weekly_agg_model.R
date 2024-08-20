# Run epinowcast() on weekly simulated data. These are the daily
# data, but aggregated to weeks.

library(dplyr)
library(epinowcast)

setwd(here::here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
sim_data_weekly <- readRDS("Data/retrospective_weekly_dat.rds")

expectation_module <- enw_expectation(
  r = ~ 1 + rw(week),
  data = sim_data_weekly
)

report_module <- enw_report(~ 1, data = sim_data_weekly)

nowcast_weekly_agg <- epinowcast(sim_data_weekly,
  expectation = expectation_module,
  report = report_module,
  reference = reference_module(data = sim_data_weekly),
  obs = obs_module(data = sim_data_weekly),
  fit = fit,
)

latest <- readRDS("Data/latest_weekly_dat.rds") |>
  enw_filter_reference_dates(earliest_date = "2024-04-03",
                             latest_date = "2024-04-26")
plot(nowcast_weekly_agg, latest_obs = latest)

diagnostic_summary <- nowcast_weekly_agg |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
