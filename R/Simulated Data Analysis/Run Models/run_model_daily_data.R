# Run epinowcast() on daily simulated data. These are the plain
# daily data without a weekly reporting cycle layererd on.
library(here)
library(dplyr)

setwd(here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
sim_data_daily <- readRDS("Data/retrospective_daily_dat.rds")

nowcast_daily_data <- epinowcast(sim_data_daily,
  expectation = expectation_module(data = sim_data_daily),
  report = enw_report(~ day_of_week,
                      data = sim_data_daily),
  reference = reference_module(data = sim_data_daily),
  obs = obs_module(data = sim_data_daily),
  fit = fit,
)

latest <- readRDS("Data/latest_daily_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast_daily_data, latest_obs = latest)

diagnostic_summary <- nowcast_daily_data |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
