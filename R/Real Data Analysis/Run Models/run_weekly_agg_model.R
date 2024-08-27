# Run epinowcast() on weekly flusurv data.

library(dplyr)
library(epinowcast)

setwd(here::here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
flu_data_weekly <- readRDS("Data/retrospective_weekly_flu_dat.rds")

# We also have "delay_0 effects" as in cfa-respnet-nowcasting
flu_data_weekly$metadelay[[1]] <- flu_data_weekly$metadelay[[1]] |>
  mutate(delay_undercounted = (delay == 0),
         delay_overcounted = (delay == 1))

# Define custom priors as in cfa-respnet-nowcasting
gamma_priors <- tibble(
  variable = c("refp_mean_int", "refp_sd_int", "expr_r_int", "expr_beta_sd"),
  mean = c(-1.04, 0.375, 0.05, .0075),
  sd = c(2.029, 0.404, .25, .15)
)

expectation_module <- enw_expectation(
  r = ~ 1 + rw(week),
  data = flu_data_weekly
)

report_module <- enw_report(~ 1, data = flu_data_weekly)

nowcast_weekly_agg <- epinowcast(flu_data_weekly,
  expectation = expectation_module,
  report = report_module,
  reference = reference_module(non_parametric = ~ 0 + delay_undercounted +
                                 delay_overcounted, data = flu_data_weekly),
  obs = obs_module(data = flu_data_weekly),
  fit = fit,
  priors = gamma_priors,
)

latest <- readRDS("Data/latest_weekly_flu_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-02-28")

plot(nowcast_weekly_agg, latest_obs = latest)

# what's going on here
fit <- nowcast_weekly_agg
x <- enw_posterior(fit$fit[[1]], variables = "pp_inf_obs")
summ <- enw_nowcast_summary(fit$fit[[1]], fit$obs[[1]], timestep = "week")

diagnostic_summary <- nowcast_weekly_agg |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
