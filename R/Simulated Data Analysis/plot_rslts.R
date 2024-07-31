library(ggplot2)
source("R/Simulated Data Analysis/Functions/get_weekly_nowcast_from_daily.R")

# Plots of nowcasts all on same frame



# Compare daily nowcasts aggregated to weekly, to weekly nowcast
nowcast_daily <- readRDS("Nowcasts/nowcast_hardcode_hzd.rds")
daily_to_weekly <- get_weekly_nowcast_from_daily(nowcast_daily,
                                                 nowcast_data = readRDS("Data/retrospective_daily_dat.rds"), # nolint
                                                 end_of_week = "Wed",
                                                 output = "summary")
ggplot(daily_to_weekly, aes(x = ref_wk)) +
  geom_line(aes(y = `50%`)) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`),
              fill =  "#1f87aa", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(aes(ymin = `20%`, ymax = `80%`, col = NULL),
              fill = "#1f87aa", alpha = 0.2) +
  ylab("Nowcast") +
  xlab("Reference Date") +
  ylim(250, 850) +
  theme_bw()

# And compare to daily nowcast aggregated to weekly
nowcast_daily <- readRDS("Nowcasts/nowcast_default.rds")
daily_to_weekly <- get_weekly_nowcast_from_daily(nowcast_daily,
                                                 nowcast_data = readRDS("Data/retrospective_daily_dat.rds"), # nolint
                                                 end_of_week = "Fri",
                                                 output = "summary")
ggplot(daily_to_weekly, aes(x = ref_wk)) +
  geom_line(aes(y = `50%`)) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`),
              fill =  "#1f87aa", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(aes(ymin = `20%`, ymax = `80%`, col = NULL),
              fill = "#1f87aa", alpha = 0.2) +
  ylab("Nowcast") +
  xlab("Reference Date") +
  ylim(250, 850) +
  theme_bw()
