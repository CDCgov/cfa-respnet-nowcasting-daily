# Note that this is the same as the hardcoded hazard effect model,
# but without the "model" argument - that is, using epinowcast
# to run a model with a hazard effect where the covariate
# is an indicator of whether the day is a reporting day.

library(here)
library(dplyr)

setwd(here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
sim_data <- readRDS("Data/retrospective_rep_cycle_dat.rds")

nowcast_hzd_eff <- epinowcast(sim_data,
  expectation = expectation_module(data = sim_data),
  reference = reference_module(data = sim_data),
  report = enw_report(~ not_report_day + (1 | day_of_week),
                      data = sim_data),
  obs = obs_module(data = sim_data),
  fit = fit
)

latest <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast_hzd_eff, latest_obs = latest)

diagnostic_summary <- nowcast_hzd_eff |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
