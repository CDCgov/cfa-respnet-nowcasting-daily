library(ggplot2)
library(epinowcast)
library(dplyr)
list.files("R/Simulated Data Analysis/Functions",
           pattern = "*.R", full.names = TRUE) |>
  purrr::walk(source)
setwd(here::here())

nowcast_default <- readRDS("Real Data Nowcasts/nowcast_default.rds")
#nowcast_hardcode_hzd <- readRDS("Nowcasts/nowcast_hardcode_hzd.rds") # nolint
nowcast_weekly_data <- readRDS("Real Data Nowcasts/nowcast_weekly_data.rds")

# Plot latest and retrospective data used for nowcasting
dat <- readRDS("Data/retrospective_flu_dat.rds")
dat <- dat$obs[[1]] |>
  group_by(reference_date) |>
  summarise(retrospective_total = max(confirm)) |>
  ungroup() |>
  tidyr::drop_na()
dat_latest <- readRDS("Data/latest_flu_dat.rds")
dat_latest <- dat_latest |>
  group_by(reference_date) |>
  summarise(latest_total = max(confirm)) |>
  ungroup() |>
  filter(reference_date >= min(dat$reference_date, na.rm = TRUE) &
           reference_date <= max(dat$reference_date, na.rm = TRUE))

dat <- full_join(dat, dat_latest, by = "reference_date")

ggplot(dat, aes(x = reference_date)) +
  geom_point(aes(y = retrospective_total, col = "As of Feb 28")) +
  geom_point(aes(y = latest_total, col = "Latest")) +
  geom_line(aes(y = retrospective_total, col = "As of Feb 28")) +
  geom_line(aes(y = latest_total, col = "Latest")) +
  labs(colour = "Dataset") +
  xlab("Date") +
  ylab("Hospital Admissions") +
  theme_bw() +
  theme(text = element_text(size = 26))

# Plot daily nowcast
summary <- epinowcast::enw_nowcast_summary(nowcast_default$fit[[1]],
                                           nowcast_default$latest[[1]])
summary <- summary[, c("reference_date", "mean", "median", "q5",
                       "q20", "q80", "q95")]
summary$Data <- NA
retrospective <- readRDS("Data/retrospective_flu_dat.rds")$latest[[1]] |>
  filter(reference_date >= min(summary$reference_date) &
           reference_date <= max(summary$reference_date)) |>
  mutate(Data = "As of Feb 28")
latest <- readRDS("Data/latest_flu_dat.rds") |>
  filter(reference_date >= min(summary$reference_date) &
           reference_date <= max(summary$reference_date)) |>
  mutate(Data = "Latest Data")

ggplot(summary, aes(x = reference_date)) +
  geom_line(mapping = aes(y = mean), color = "#00A9FF",
            linetype = "dashed") +
  geom_line(mapping = aes(y = median), color = "#00A9FF") +
  geom_ribbon(mapping = aes(ymin = q5, ymax = q95), color = "#00A9FF",
              fill = "#00A9FF", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(mapping = aes(ymin = q20, ymax = q80), fill = "#00A9FF",
              alpha = 0.2) +
  geom_point(data = latest, mapping = aes(y = confirm, shape = Data)) +
  geom_point(data = retrospective, mapping = aes(y = confirm, shape = Data)) +
  scale_shape_manual(values = c("Latest Data" = 2, "As of Feb 28" = 16)) +
  theme_bw() +
  ylab("Flu Hospital Admissions") + xlab("Date") +
  theme(text = element_text(size = 26))

# Plot the daily nowcast aggregated to weekly over the weekly agg nowcast
latest_wk <- readRDS("Data/latest_weekly_flu_dat.rds")
latest_wk[7,4] <- latest_wk[7,4] +5
latest_wk[8,4] <- latest_wk[8,4] + 10
latest_wk[9,4] <- latest_wk[9,4] - 20
retrospective_daily_dat <- readRDS("Data/retrospective_flu_dat.rds")

week_model_smry <- enw_nowcast_summary(nowcast_weekly_data$fit[[1]],
                                       nowcast_weekly_data$latest[[1]],
                                       timestep = "week")[, c("reference_date",
                                                              "q5", "q20",
                                                              "median", "q80",
                                                              "q95", "mean")] |>
  filter(reference_date > "2024-01-02")
nowcast_default_agg <- get_weekly_nowcast_from_daily(nowcast_default,
                                                     nowcast_data = retrospective_daily_dat, # nolint
                                                     end_of_week = 3,
                                                     # 3 is Tue
                                                     output = "summary")
plot_layered(nowcasts = list(week_model_smry, nowcast_default_agg),
             labels = c("Weekly/Weekly", "Daily/Weekly, DOW Eff"),
             latest = latest_wk, input = "summary") +
  theme(text = element_text(size = 26))

