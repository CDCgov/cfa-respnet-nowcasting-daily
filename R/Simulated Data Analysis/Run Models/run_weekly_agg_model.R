# Run epinowcast() on weekly simulated data. These are the daily
# data, but aggregated to weeks.

library(dplyr)
library(epinowcast)

setwd(here::here())
sim_data_weekly <- readRDS("Data/retrospective_weekly_dat.rds")

fit <- enw_fit_opts(
  save_warmup = FALSE, pp = TRUE,
  chains = 4, threads_per_chain = 1,
  parallel_chains = 4,
  iter_warmup = 1000, iter_sampling = 2000,
  adapt_delta = 0.98, max_treedepth = 12
)

expectation_module <- enw_expectation(
  r = ~ 1 + rw(week),
  data = sim_data_weekly
)

reference_module <- enw_reference(parametric = ~ 1,
                                  distribution = "gamma",
                                  data = sim_data_weekly)

report_module <- enw_report(~ 1, data = sim_data_weekly)

obs_module <- enw_obs(family = "negbin", data = sim_data_weekly)

nowcast_weekly_agg <- epinowcast(sim_data_weekly,
  expectation = expectation_module,
  report = report_module,
  reference = reference_module,
  obs = obs_module,
  fit = fit,
)

latest <- readRDS("Data/latest_weekly_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-05-01")
plot(nowcast_weekly_agg, latest_obs = latest)

diagnostic_summary <- nowcast_weekly_agg |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
