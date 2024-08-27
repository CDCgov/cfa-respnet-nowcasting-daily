# File to process RESPNET flu data. Keeping
# Feb-now, population 65+
library(dplyr)
library(epinowcast)

setwd(here::here())

# Read the flusurv csv files
all_files <- list.files(
  path = "~/S/CFA/FLUSurv_NET/Count Files/", pattern = "*.csv",
  full.names = TRUE, recursive = FALSE
)

# Keep files from the 23-24 season
files <- all_files[stringr::str_detect(
  all_files,
  stringr::str_glue("{2324}_")
)]

# Read the files and add report_date for each from the filename
pattern <- "_(\\d{8}).csv$"
data_list <- lapply(files, read.csv)
data_list <- lapply(seq_len(length(data_list)), function(idx) {
  data_list[[idx]] <- data_list[[idx]] |>
    mutate(
      report_date = as.Date(stringr::str_match(files[[idx]], pattern)[, 2],
        format = "%Y%m%d"
      )
    )
})
flu_data <- data_list |>
  bind_rows() |>
  mutate(
    reference_date = as.Date(`X_admdate`, format = "%m/%d/%Y")
  ) |>
  filter(report_date >= "2023-09-01",
         X_age >= 65) |>
  select(report_date, reference_date, CaseID) |>
  group_by(reference_date) |>
  arrange(report_date) |>
  ungroup()
## some extra steps here because i'm unclear if the
# files are completely cumulative? will change above if true
flu_data <- flu_data[!duplicated(flu_data$CaseID), ]

flu_data <- flu_data |>
  enw_linelist_to_incidence() |>
  enw_complete_dates() |>
  mutate(day_of_week = lubridate::wday(report_date, label = TRUE))

# Get both retrospective and latest observations, and save
# Noting here that minimum delay is 3 days prob due to weekend
# not sure if it will be a problem with the model as is
flu_data_retrospective <- flu_data |>
  enw_filter_report_dates(latest_date = "2024-02-28") |>
  enw_filter_reference_dates(include_days = 100) |>
  mutate(.observed = ifelse(day_of_week == "Tue", TRUE, FALSE)) |>
  mutate(not_report_day = ifelse(day_of_week != "Tue",
                                 1,
                                 0)) |>
  enw_preprocess_data()
saveRDS(flu_data_retrospective, "Data/retrospective_flu_dat.rds")

flu_data_latest <- flu_data |>
  filter(day_of_week == "Tue") |>
  enw_latest_data()
saveRDS(flu_data_latest, "Data/latest_flu_dat.rds")

# Aggregate reporting cycle data to weekly data
flu_data_weekly_retrospective <- flu_data |>
  enw_filter_report_dates(latest_date = "2024-02-28") |>
  enw_filter_reference_dates(include_days = 98) |>
  mutate(.observed = ifelse(day_of_week == "Tue", TRUE, FALSE)) |>
  mutate(not_report_day = ifelse(day_of_week != "Tue",
                                 1,
                                 0)) |>
  enw_aggregate_cumulative(timestep = "week") |>
  enw_preprocess_data(timestep = "week")
saveRDS(flu_data_weekly_retrospective, "Data/retrospective_weekly_flu_dat.rds")

flu_data_weekly_latest <- flu_data |>
  enw_filter_reference_dates(earliest_date = "2023-11-22") |>
  enw_aggregate_cumulative(timestep = "week") |>
  enw_latest_data()
saveRDS(flu_data_weekly_latest, "Data/latest_weekly_flu_dat.rds")
