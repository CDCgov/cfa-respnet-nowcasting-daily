library(here)
library(dplyr)

setwd(here())
source(file.path("R", "Simulated Data Analysis", "Run Models",
                 "model_definition.R"))
flu_data <- readRDS("Data/retrospective_flu_dat.rds")

# We also have "delay_0 effects" as in cfa-respnet-nowcasting
flu_data$metadelay[[1]] <- flu_data$metadelay[[1]] |>
  mutate(delay_undercounted = (delay < 3),
         delay_overcounted = (delay >= 7 & delay <= 9))

# Define custom priors as in cfa-respnet-nowcasting
gamma_priors <- tibble(
  variable = c("refp_mean_int", "refp_sd_int", "expr_r_int", "expr_beta_sd"),
  mean = c(-1.04, 0.375, 0.05, .0075),
  sd = c(2.029, 0.404, .25, .15)
)
# Adjust for weekly -> daily scale
# Scale up parametric delay by 7 (add log 7 to the mean/sd)
gamma_priors[1, 2:3] <- log(7) + gamma_priors[1, 2:3]
# Scale down the growth rate (already multiplicative, so just divide by 7)
gamma_priors[3:4, 2:3] <- gamma_priors[3:4, 2:3] / 7


# Use the model where hazard effects are hardcoded
model <- enw_model(
  model = here("Stan/hardcode_hzd_effect.stan"),
  threads = TRUE, stanc_options = list("O1"),
  include = system.file("stan", package = "epinowcast")
)

nowcast <- epinowcast(flu_data,
  expectation = expectation_module(data = flu_data),
  reference = reference_module(data = flu_data),
  report = enw_report(~ not_report_day,
                      data = flu_data),
  obs = obs_module(observation_indicator = ".observed",
                   data = flu_data),
  fit = fit,
  model = model
)

latest <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
plot(nowcast, latest_obs = latest)

diagnostic_summary <- nowcast |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)
