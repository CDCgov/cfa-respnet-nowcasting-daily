# Run epinowcast() on daily simulated data. These are the plain
# data without a weekly reporting cycle layererd on.

library(dplyr)
library(epinowcast)

setwd(here::here())
sim_data_daily <- readRDS("Data/retrospective_daily_dat.rds")

fit <- enw_fit_opts(
  save_warmup = FALSE, pp = TRUE,
  chains = 4, threads_per_chain = 1,
  parallel_chains = 4,
  iter_warmup = 1000, iter_sampling = 2000,
  adapt_delta = 0.98, max_treedepth = 12
)

expectation_module <- enw_expectation(
  r = ~ 1 + rw(day),
  data = sim_data_daily
)

reference_module <- enw_reference(parametric = ~ 1,
                                  distribution = "gamma",
                                  data = sim_data_daily)

report_module <- enw_report(~ (1 | day_of_week),
                            data = sim_data_daily)

obs_module <- enw_obs(family = "negbin", data = sim_data_daily)

nowcast_daily_data <- epinowcast(sim_data_daily,
  expectation = expectation_module,
  report = report_module,
  reference = reference_module,
  obs = obs_module,
  fit = fit,
)

latest <- readRDS("Data/latest_daily_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast_daily_data, latest_obs = latest)

diagnostic_summary <- nowcast_daily_data |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
