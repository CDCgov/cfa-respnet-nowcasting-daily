library(here)
library(dplyr)

setwd(here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
sim_data <- readRDS("Data/retrospective_rep_cycle_dat.rds")

# Use the model where hazard effects are hardcoded
model <- enw_model(
  model = here("Stan/hardcode_hzd_effect.stan"),
  threads = TRUE, stanc_options = list("O1"),
  include = system.file("stan", package = "epinowcast")
)

nowcast <- epinowcast(sim_data,
  expectation = expectation_module(data = sim_data),
  reference = reference_module(data = sim_data),
  report = enw_report(~ not_report_day,
                      data = sim_data),
  obs = obs_module(observation_indicator = ".observed",
                   data = sim_data),
  fit = fit,
  model = model
)

latest <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-24")
plot(nowcast, latest_obs = latest)

diagnostic_summary <- nowcast |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
