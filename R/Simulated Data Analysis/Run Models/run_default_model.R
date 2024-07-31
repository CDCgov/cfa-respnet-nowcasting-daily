# Run epinowcast on defaults using the weekly fixed
# reporting cycle data. Note that this is the same as
# the model with the hazard effect, but with the default
# settings for the report module. In other words, here
# we're just running epinowcast as normal but with
# the fixed reporting cycle data.
library(here)
library(dplyr)
library(epinowcast)

setwd(here())
# Note the last reference_date available in these data is Friday, 4/26
sim_data <- readRDS("Data/retrospective_rep_cycle_dat.rds")

expectation_module <- enw_expectation(
  r = ~ 1 + rw(day),
  data = sim_data
)

reference_module <- enw_reference(parametric = ~ 1,
                                  distribution = "gamma",
                                  data = sim_data)

report_module <- enw_report(~ (1 | day_of_week), data = sim_data)

obs_module <- enw_obs(family = "negbin",
                      data = sim_data)

# Priors?

nowcast_default <- epinowcast(sim_data,
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
  )
)


latest <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast_default, latest_obs = latest)

diagnostic_summary <- nowcast_default |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
