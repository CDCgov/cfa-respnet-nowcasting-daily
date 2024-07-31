library(ggplot2)
library(epinowcast)
list.files("R/Simulated Data Analysis/Functions",
           pattern = "*.R", full.names = TRUE) |>
  purrr::walk(source)

nowcast_daily <- readRDS("Nowcasts/nowcast_daily_data.rds")
nowcast_default <- readRDS("Nowcasts/nowcast_default.rds")
nowcast_hzd_eff <- readRDS("Nowcasts/nowcast_hzd_eff.rds")
nowcast_hardcode_hzd <- readRDS("Nowcasts/nowcast_hardcode_hzd.rds")

# Plots of nowcasts all on same frame
plt <- plot_layered(nowcasts = list(nowcast_daily, nowcast_default,
                                    nowcast_hzd_eff, nowcast_hardcode_hzd),
                    labels = c("Daily/Daily", "DOW Random Eff",
                               "Hazard Eff", "Hardcoded Hzd"))
latest_obs <- readRDS("Data/latest_rep_cycle_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
latest_obs <- epinowcast:::coerce_dt(latest_obs)
latest_obs[, latest_confirm := confirm]
latest_obs <- cbind(latest_obs, "Model" = "latest observations")
plot <- plt +
  geom_point(
    data = latest_obs, aes(y = latest_confirm),
    na.rm = TRUE, alpha = 1, size = 1.5, shape = 2
  )
plot

# Compare daily nowcasts aggregated to weekly, to weekly nowcast
nowcast_weekly_data <- readRDS("Nowcasts/nowcast_weekly_data.rds")
daily_to_weekly <- get_weekly_nowcast_from_daily(nowcast_hardcode_hzd,
                                                 nowcast_data = readRDS("Data/retrospective_daily_dat.rds"), # nolint
                                                 end_of_week = "Wed",
                                                 output = "summary")
p4 <- ggplot(daily_to_weekly, aes(x = ref_wk)) +
  geom_line(aes(y = `50%`)) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`),
              fill =  "#1f87aa", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(aes(ymin = `20%`, ymax = `80%`, col = NULL),
              fill = "#1f87aa", alpha = 0.2) +
  ylab("Nowcast") +
  xlab("Reference Date") +
  ylim(250, 850) +
  theme_bw()
latest <- readRDS("Data/latest_weekly_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
p5 <- plot(nowcast_weekly_data, latest)
library(patchwork)
(p1 + p2) / (p3 + p4) / p5
