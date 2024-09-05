# Run epinowcast using the fixed weekly reporting cycle data.
# This model accounts for the rep cycle data using a DOW
# fixed effect on the report day of week.
library(here)
library(dplyr)

setwd(here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
sim_data <- readRDS("Data/retrospective_rep_cycle_dat.rds")

nowcast_DOW <- epinowcast(sim_data,
  expectation = expectation_module(data = sim_data),
  reference = reference_module(data = sim_data),
  report = enw_report(~ day_of_week, data = sim_data),
  obs = obs_module(data = sim_data),
  fit = fit
)

latest <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast_DOW, latest_obs = latest)

diagnostic_summary <- nowcast_DOW |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
