library(here)
library(dplyr)
library(epinowcast)

setwd(here())
sim_data <- readRDS("Data/retrospective_rep_cycle_dat.rds")

model <- enw_model(
  model = here("Stan/hardcode_hzd_effect.stan"),
  threads = TRUE, stanc_options = list("O1"),
  include = system.file("stan", package = "epinowcast")
)

expectation_module <- enw_expectation(
  r = ~ 1 + rw(day),
  data = sim_data
)

reference_module <- enw_reference(parametric = ~ 1,
                                  distribution = "gamma",
                                  data = sim_data)

report_module <- enw_report(~ not_report_day,
                            data = sim_data)

obs_module <- enw_obs(family = "negbin", observation_indicator = ".observed",
                      data = sim_data)


nowcast <- epinowcast(sim_data,
  expectation = expectation_module,
  reference = reference_module,
  report = report_module,
  obs = obs_module,
  fit = enw_fit_opts(
    save_warmup = FALSE, pp = TRUE,
    chains = 4, threads_per_chain = 1,
    parallel_chains = 4,
    iter_warmup = 1000, iter_sampling = 2000,
    adapt_delta = 0.98, max_treedepth = 12
  ),
  model = model
)

latest <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast, latest_obs = latest)

diagnostic_summary <- nowcast |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
