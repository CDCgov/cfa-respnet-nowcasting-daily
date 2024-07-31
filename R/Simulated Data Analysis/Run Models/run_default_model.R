# Run epinowcast on defaults using the weekly fixed
# reporting cycle data. Note that this is the same as
# the model with the hazard effect, but with the default
# settings for the report module. In other words, here
# we're just running epinowcast as normal but with
# the fixed reporting cycle data.
library(here)
library(dplyr)

setwd(here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
sim_data <- readRDS("Data/retrospective_rep_cycle_dat.rds")

nowcast_default <- epinowcast(sim_data,
  expectation = expectation_module(data = sim_data),
  reference = reference_module(data = sim_data),
  report = enw_report(~ (1 | day_of_week), data = sim_data),
  obs = obs_module(data = sim_data),
  fit = fit
)

latest <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast_default, latest_obs = latest)

diagnostic_summary <- nowcast_default |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
