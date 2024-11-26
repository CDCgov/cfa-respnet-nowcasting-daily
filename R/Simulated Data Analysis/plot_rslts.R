library(ggplot2)
library(epinowcast)
library(dplyr)
list.files("R/Simulated Data Analysis/Functions",
           pattern = "*.R", full.names = TRUE) |>
  purrr::walk(source)
setwd(here::here())

# Code assumes rds files of model runs saved into a
# Nowcasts directory
nowcast_daily <- readRDS("Nowcasts/nowcast_daily_data.rds")
nowcast_DOW <- readRDS("Nowcasts/nowcast_DOW.rds")
nowcast_hardcode_hzd <- readRDS("Nowcasts/nowcast_hardcode_hzd.rds")
nowcast_weekly_data <- readRDS("Nowcasts/nowcast_weekly_data.rds")

# Plot latest and retrospective data used for nowcasting
dat <- readRDS("Data/retrospective_rep_cycle_dat.rds")
dat <- dat$obs[[1]] |>
  group_by(reference_date) |>
  summarise(retrospective_total = max(confirm)) |>
  ungroup() |>
  tidyr::drop_na()
dat_latest <- readRDS("Data/latest_rep_cycle_dat.rds")
dat_latest <- dat_latest |>
  group_by(reference_date) |>
  summarise(latest_total = max(confirm)) |>
  ungroup() |>
  filter(reference_date >= min(dat$reference_date, na.rm = TRUE) &
           reference_date <= max(dat$reference_date, na.rm = TRUE))

dat <- full_join(dat, dat_latest, by = "reference_date")

ggplot(dat, aes(x = reference_date)) +
  geom_point(aes(y = retrospective_total, col = "As of Apr 26")) +
  geom_point(aes(y = latest_total, col = "Latest")) +
  geom_line(aes(y = retrospective_total, col = "As of Apr 26")) +
  geom_line(aes(y = latest_total, col = "Latest")) +
  labs(colour = "Dataset") +
  xlab("Date") +
  ylab("Hospital Admissions") +
  theme_bw() +
  theme(text = element_text(size = 26))


# Plot each daily nowcast on top of the daily/daily
latest <- readRDS("Data/latest_daily_dat.rds")
plot_layered(nowcasts = list(nowcast_daily, nowcast_DOW),
             labels = c("Daily/Daily", "Daily/Weekly, DOW Eff"),
             latest = latest)  +
  theme(text = element_text(size = 26))
plot_layered(nowcasts = list(nowcast_daily, nowcast_hardcode_hzd),
             labels = c("Daily/Daily", "Daily/Weekly, Hardcoded\nHazard"),
             latest = latest)  +
  theme(text = element_text(size = 26))
ggsave("dailydaily_vs_hardcodehzd.svg", plot = x, width = 16.25, height = 5)



# Plot each daily nowcast, aggregated to weekly, on top of weekly/weekly
latest_wk <- readRDS("Data/latest_weekly_dat.rds")
retrospective_rep_cycle_dat <- readRDS("Data/retrospective_rep_cycle_dat.rds")
week_model_smry <- enw_nowcast_summary(nowcast_weekly_data$fit[[1]],
                                       nowcast_weekly_data$latest[[1]],
                                       timestep = "week")[, c("reference_date",
                                                              "q5", "q20",
                                                              "median", "q80",
                                                              "q95", "mean")]
nowcast_DOW_agg <- get_weekly_nowcast_from_daily(nowcast_DOW,
                                                     nowcast_data = retrospective_rep_cycle_dat, # nolint
                                                     end_of_week = 4,
                                                     # 4 is Wed
                                                     output = "summary")
nowcast_hardcode_agg <- get_weekly_nowcast_from_daily(nowcast_hardcode_hzd,
                                                      nowcast_data = retrospective_daily_dat, # nolint
                                                      end_of_week = 4,
                                                      output = "summary")
plot_layered(nowcasts = list(week_model_smry, nowcast_DOW_agg),
             labels = c("Weekly/Weekly", "Daily/Weekly, DOW Eff"),
             latest = latest_wk, input = "summary")  +
  theme(text = element_text(size = 26))

plot_layered(nowcasts = list(week_model_smry, nowcast_hardcode_agg),
             labels = c("Weekly/Weekly", "Daily/Weekly, Hardcoded Hazard"),
             latest = latest_wk, input = "summary")  +
  theme(text = element_text(size = 26))

# Also aggregate daily/daily & plot
dailydaily_agg <- get_weekly_nowcast_from_daily(nowcast_daily,
                                                nowcast_data = retrospective_daily_dat, # nolint
                                                end_of_week = 4,
                                                output = "summary")
plot_layered(nowcasts = list(week_model_smry, dailydaily_agg),
             labels = c("Weekly/Weekly", "Daily/Daily"),
             latest = latest_wk, input = "summary")  +
  theme(text = element_text(size = 26))


# Diagnostics
nowcast_weekly_data |>
  bind_rows() |>
  select(divergent_transitions, max_rhat, max_treedepth, no_at_max_treedepth)


# Look at DOW effects
post_daily <- enw_posterior(nowcast_daily$fit[[1]], variables = "rep_beta")
post_DOW <- enw_posterior(nowcast_DOW$fit[[1]], variables = "rep_beta")

# Posterior predictions
plot(nowcast_weekly_data , type = "posterior") +
  facet_wrap(vars(reference_date), scales = "free")
