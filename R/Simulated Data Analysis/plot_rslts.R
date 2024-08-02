library(ggplot2)
library(epinowcast)
library(dplyr)
list.files("R/Simulated Data Analysis/Functions",
           pattern = "*.R", full.names = TRUE) |>
  purrr::walk(source)

nowcast_daily <- readRDS("Nowcasts/nowcast_daily_data.rds")
nowcast_default <- readRDS("Nowcasts/nowcast_default.rds")
nowcast_hzd_eff <- readRDS("Nowcasts/nowcast_hzd_eff.rds")
nowcast_hardcode_hzd <- readRDS("Nowcasts/nowcast_hardcode_hzd.rds")

# Plot latest and retrospective data used for nowcasting
dat <- readRDS("/Users/jessalynsebastian/Code/cfa-respnet-nowcasting-daily/Data/retrospective_daily_dat.rds")
dat <- dat$obs[[1]] |>
  group_by(reference_date) |>
  summarise(retrospective_total = max(confirm)) |>
  ungroup() |>
  tidyr::drop_na()
dat_latest <- readRDS("/Users/jessalynsebastian/Code/cfa-respnet-nowcasting-daily/Data/latest_rep_cycle_dat.rds")
dat_latest <- dat_latest |>
  group_by(reference_date) |>
  summarise(latest_total = max(confirm)) |>
  ungroup() |>
  filter(reference_date >= min(dat$reference_date, na.rm = TRUE) &
                  reference_date <= max(dat$reference_date, na.rm = TRUE))

dat <- full_join(dat, dat_latest, by = "reference_date")

ggplot(dat, aes(x = reference_date)) +
  geom_point(aes(y = retrospective_total, col = "Retrospective")) +
  geom_point(aes(y = latest_total, col = "Latest")) +
  geom_line(aes(y = retrospective_total, col = "Retrospective")) +
  geom_line(aes(y = latest_total, col = "Latest")) +
  labs(colour = "Dataset") +
  xlab("Date") +
  ylab("Hospital Admissions") +
  theme_bw()


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

# Look at DOW random effects 
post_daily <- enw_posterior(nowcast_daily$fit[[1]], variables = "rep_beta")
post_default <- enw_posterior(nowcast_default$fit[[1]], variables = "rep_beta")
post_hzd_eff <- enw_posterior(nowcast_hzd_eff$fit[[1]], variables = "rep_beta")
# TODO: run hardcode hzd model with DOW effect

# Compare daily nowcasts aggregated to weekly, to weekly nowcast
nowcast_weekly_data <- readRDS("Nowcasts/nowcast_weekly_data.rds")
daily_to_weekly <- get_weekly_nowcast_from_daily(nowcast_default,
                                                 nowcast_data = readRDS("Data/retrospective_daily_dat.rds"), # nolint
                                                 end_of_week = "Wed",
                                                 output = "summary")
p1 <- ggplot(daily_to_weekly, aes(x = ref_wk)) +
  geom_line(aes(y = `50%`)) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`),
              fill =  "#1f87aa", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(aes(ymin = `20%`, ymax = `80%`, col = NULL),
              fill = "#1f87aa", alpha = 0.2) +
  ylab("Nowcast") +
  xlab("Reference Date") +
  ylim(250, 850) +
  theme_bw()  + ggtitle("Daily/Daily")

p2 <- ggplot(daily_to_weekly, aes(x = ref_wk)) +
  geom_line(aes(y = `50%`)) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`),
              fill =  "#1f87aa", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(aes(ymin = `20%`, ymax = `80%`, col = NULL),
              fill = "#1f87aa", alpha = 0.2) +
  ylab("Nowcast") +
  xlab("Reference Date") +
  ylim(250, 850) +
  theme_bw() + ggtitle("Rep Cycle - DOW Effect")


p3 <- ggplot(daily_to_weekly, aes(x = ref_wk)) +
  geom_line(aes(y = `50%`)) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`),
              fill =  "#1f87aa", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(aes(ymin = `20%`, ymax = `80%`, col = NULL),
              fill = "#1f87aa", alpha = 0.2) +
  ylab("Nowcast") +
  xlab("Reference Date") +
  ylim(250, 850) +
  theme_bw() + ggtitle("Rep Cycle - Hzd Effect")

p4 <- ggplot(daily_to_weekly, aes(x = ref_wk)) +
  geom_line(aes(y = `50%`)) +
  geom_ribbon(aes(ymin = `5%`, ymax = `95%`),
              fill =  "#1f87aa", alpha = 0.2, linewidth = 0.2) +
  geom_ribbon(aes(ymin = `20%`, ymax = `80%`, col = NULL),
              fill = "#1f87aa", alpha = 0.2) +
  ylab("Nowcast") +
  xlab("Reference Date") +
  ylim(250, 850) +
  theme_bw() + ggtitle("Rep Cycle - Hardcode Hzd Eff")
latest <- readRDS("Data/latest_weekly_dat.rds") |>
  enw_filter_reference_dates(include_days = 28,
                             latest_date = "2024-04-26")
p5 <- plot(nowcast_weekly_data, latest) + ggtitle("Aggregated Weekly Data")
library(patchwork)
(p1 + p2) / (p3 + p4) / p5
