# Run epinowcast() on weekly simulated data. These are the daily
# data, but aggregated to weeks.

library(dplyr)
library(epinowcast)

setwd(here::here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
sim_data_weekly <- readRDS("Data/retrospective_weekly_dat.rds")
sim_data_weekly$metadelay[[1]] <- sim_data_weekly$metadelay[[1]] |>
  mutate(delay_0 = delay == 0) |>
  mutate(delay_1 = delay == 1)

expectation_module <- enw_expectation(
  r = ~ 1 + rw(week),
  data = sim_data_weekly
)

report_module <- enw_report(~ 1, data = sim_data_weekly)

# Need to adjust priors because epinowcast was built for daily models
# Growth rate (scale up for longer timestep)
expectation_module$priors[1, 5:6] <-  expectation_module$priors[1, 5:6] * 7

# Parametric reference date delay (scale down for longer timestep)
reference_module <- reference_module(non_parametric = ~ delay_0 + delay_1,
                                     data = sim_data_weekly)
reference_module$priors[1, 4] <- reference_module$priors[1, 4] - log(7)
reference_module$priors[1, 5] <- reference_module$priors[1, 5] + log(7)

nowcast_weekly_agg <- epinowcast(sim_data_weekly,
  expectation = expectation_module,
  report = report_module,
  reference = reference_module,
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
