library(epinowcast)
library(dplyr)
library(tidyr)
library(here)

setwd(here::here())
sim_data_saved <- read.csv("Data/sim_data.csv")[, -1]
# Sim data generated with functions in sim_hospital_admissions.R
colnames(sim_data_saved) <- c("reference_date", "report_date")
sim_data <- sim_data_saved |>
  mutate_all(~ as.Date(.x))

# Get incidence from linelist
sim_data <- sim_data |>
  enw_linelist_to_incidence(max_delay = 28) |>
  enw_complete_dates(max_delay = 28) |>
  mutate(day_of_week = lubridate::wday(report_date, label = TRUE))

#### DAILY DATA ####
# Get both retrospective and latest observations, and save (this
# will be the daily data)
sim_data_retrospective <- sim_data |>
  enw_filter_report_dates(latest_date = "2024-04-24") |>
  enw_filter_reference_dates(earliest_date = "2024-02-01",
                             latest_date = "2024-04-24") |>
  mutate(.observed = ifelse(day_of_week == "Wed", TRUE, FALSE)) |>
  enw_preprocess_data(max_delay = 28)
saveRDS(sim_data_retrospective, "Data/retrospective_daily_dat.rds")

sim_data_latest <- sim_data |>
  filter(day_of_week == "Wed") |>
  enw_latest_data()
saveRDS(sim_data_latest, "Data/latest_daily_dat.rds")

#### REPORTING CYCLE DATA ####
# Layer on reporting cycle
rep_cycle_data <- sim_data |>
  mutate(confirm = new_confirm) |>
  # agg rolling sum is coded to sum over "confirm"
  # which for us is new_confirm, hence the overwrite
  # of confirm
  epinowcast:::aggregate_rolling_sum(
    internal_timestep = 7,
    by = "reference_date"
  ) |>
  mutate(confirm = ifelse(day_of_week == "Wed",
                          confirm,
                          0)) |>
  mutate(not_report_day = ifelse(day_of_week != "Wed",
                                 1,
                                 0)) |>
  # now we can go back and get cumulative again
  mutate(confirm = cumsum(confirm), .by = "reference_date")

# Now we want both a retrospective dataset and one with the most
# up to date obs
sim_data_retrospective <- rep_cycle_data |>
  enw_filter_report_dates(latest_date = "2024-04-24") |>
  enw_filter_reference_dates(earliest_date = "2024-02-01",
                             latest_date = "2024-04-24") |>
  mutate(.observed = ifelse(day_of_week == "Wed", TRUE, FALSE)) |>
  enw_preprocess_data(max_delay = 28)
saveRDS(sim_data_retrospective, "Data/retrospective_rep_cycle_dat.rds")

sim_data_latest <- rep_cycle_data |>
  filter(day_of_week == "Wed") |>
  enw_latest_data()
saveRDS(sim_data_latest, "Data/latest_rep_cycle_dat.rds")

#### AGGREGATE DAILY TO WEEKLY DATA ####
# Shouldn't specify a max_delay before using enw_aggregate_cumulative
# Starting from saved sim data:
sim_data <- sim_data_saved |>
  mutate_all(~ as.Date(.x)) |>
  enw_linelist_to_incidence() |>
  enw_complete_dates() |>
  mutate(day_of_week = lubridate::wday(report_date, label = TRUE))

sim_data_weekly_retrospective <- sim_data |>
  enw_filter_report_dates(latest_date = "2024-04-24") |>
  enw_filter_reference_dates(earliest_date = "2024-01-31",
                             latest_date = "2024-04-24") |>
  enw_aggregate_cumulative(timestep = "week") |>
  enw_preprocess_data(max_delay = 4,
                      timestep = "week")
saveRDS(sim_data_weekly_retrospective, "Data/retrospective_weekly_dat.rds")

sim_data_weekly_latest <- sim_data |>
  enw_filter_reference_dates(earliest_date = "2024-02-01") |>
  enw_aggregate_cumulative(timestep = "week") |>
  enw_latest_data()
saveRDS(sim_data_weekly_latest, "Data/latest_weekly_dat.rds")
