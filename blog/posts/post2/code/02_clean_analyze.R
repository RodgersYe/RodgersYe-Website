# ============================================================
# Blog Post 2
# Cleaning and Analysis of Drexel University Events
#
# Research Question:
# Which day or days of the week offer the most opportunities
# among events currently listed on the Drexel University
# Events Calendar for 2026?
#
# Research Period:
# January 1, 2026 - December 31, 2026
#
# Data Source:
# Drexel University Events Calendar
# https://calendar.drexel.edu/EventList.aspx
#
# Purpose of this script:
# 1. Read the raw event data created by 01_scrape_events.R
# 2. Clean cancelled, duplicated, and other problematic records
# 3. Examine multi-day events
# 4. Create weekday variables
# 5. Analyze the distribution of events across weekdays
# 6. Create tables and figures for Blog Post 2
# 7. Save the cleaned dataset
#
# Note:
# The raw data should not be modified manually.
# All cleaning and analysis should be reproducible through code.
# ============================================================



# 1. Load packages --------------------------------------------------------

library(here)
library(rvest)
library(robotstxt)
library(tidyverse)
library(lubridate)


# 2. Read raw data --------------------------------------------------------

# Define the research period
start_date <- ymd("2026-01-01")
end_date   <- ymd("2026-12-31")

# Define the path to the raw dataset
raw_file_path <- here(
  "blog",
  "posts",
  "post2",
  "data",
  "raw",
  "drexel_events_raw.csv"
)

# Check that the raw data file exists
file.exists(raw_file_path)


# Read the raw dataset
raw_events <- read_csv(
  raw_file_path,
  show_col_types = FALSE
)

# Make sure date variables are stored as Date objects
raw_events <- raw_events |>
  mutate(
    event_id = as.character(event_id),
    information_id = as.character(information_id),
    event_date = ymd(event_date),
    source_month = ymd(source_month),
    scraped_at = ymd(scraped_at)
  )


# 3. Inspect and validate raw data ----------------------------------------

# Check the overall structure of the dataset
glimpse(raw_events)

# Check the number of rows and columns
dim(raw_events)

# Check the variable names
names(raw_events)

# Preview the first 10 records
head(raw_events, 10)

# Check the date range
range(
  raw_events$event_date,
  na.rm = TRUE
)

# Check whether all records fall within the research period
raw_events |>
  summarise(
    before_start_date = sum(
      event_date < start_date,
      na.rm = TRUE
    ),
    after_end_date = sum(
      event_date > end_date,
      na.rm = TRUE
    )
  )

# Check missing values in important variables
raw_events |>
  summarise(
    missing_event_id = sum(is.na(event_id)),
    missing_information_id = sum(is.na(information_id)),
    missing_event_title = sum(is.na(event_title)),
    missing_event_date = sum(is.na(event_date)),
    missing_row_text = sum(is.na(row_text)),
    missing_event_url = sum(is.na(event_url))
  )

# Check the number of event records by month
monthly_counts_raw <- raw_events |>
  count(
    source_month,
    name = "number_of_events"
  ) |>
  arrange(source_month)
monthly_counts_raw

# Check the total number of raw event records
nrow(raw_events)



# 4. Identify and remove cancelled events --------------------------------

# Create a cancellation indicator.
# The calendar may use either "Cancelled" or "Canceled",
# so both spellings are included and matching is case-insensitive.
raw_events <- raw_events |>
  mutate(
    is_cancelled = str_detect(
      event_title,
      regex(
        "\\b(cancelled|canceled)\\b",
        ignore_case = TRUE
      )
    )
  )

# Count cancelled and non-cancelled event records
raw_events |>
  count(
    is_cancelled,
    name = "number_of_records"
  )

# Preview cancelled event records
raw_events |>
  filter(is_cancelled) |>
  select(
    event_id,
    information_id,
    event_title,
    event_date,
    row_text
  ) |>
  head(20)

# Count the number of cancelled event records
cancelled_record_count <- raw_events |>
  filter(is_cancelled) |>
  nrow()
cancelled_record_count

# Count the number of unique cancelled events
cancelled_unique_events <- raw_events |>
  filter(is_cancelled) |>
  distinct(event_id) |>
  nrow()
cancelled_unique_events

# Remove cancelled event records
events_no_cancelled <- raw_events |>
  filter(!is_cancelled)

# Compare the number of records before and after removing cancellations
tibble(
  dataset = c(
    "Raw data",
    "After removing cancelled events"
  ),
  number_of_records = c(
    nrow(raw_events),
    nrow(events_no_cancelled)
  )
)

# Confirm that no cancelled events remain
events_no_cancelled |>
  filter(
    str_detect(
      event_title,
      regex(
        "\\b(cancelled|canceled)\\b",
        ignore_case = TRUE
      )
    )
  )

# 5. Examine multi-day and repeated events -------------------------------

# Create an indicator for events explicitly labeled as multi-day events
events_no_cancelled <- events_no_cancelled |>
  mutate(
    is_multi_day = str_detect(
      event_title,
      regex(
        "\\(Multi-Day Event\\)",
        ignore_case = TRUE
      )
    )
  )

# Count multi-day and non-multi-day event records
events_no_cancelled |>
  count(
    is_multi_day,
    name = "number_of_records"
  )

# Count the number of unique multi-day events
multi_day_unique_count <- events_no_cancelled |>
  filter(is_multi_day) |>
  distinct(event_id) |>
  nrow()
multi_day_unique_count


# Summarize each multi-day event
multi_day_summary <- events_no_cancelled |>
  filter(is_multi_day) |>
  group_by(
    event_id,
    event_title
  ) |>
  summarise(
    first_date = min(event_date),
    last_date = max(event_date),
    number_of_listed_dates = n_distinct(event_date),
    number_of_information_ids = n_distinct(information_id),
    .groups = "drop"
  ) |>
  arrange(
    desc(number_of_listed_dates)
  )

# Preview the multi-day events with the most listed dates
multi_day_summary |>
  head(20)

# Check all events that appear on more than one date,
# whether or not they are explicitly labeled "Multi-Day Event"
repeated_event_summary <- events_no_cancelled |>
  group_by(
    event_id,
    event_title
  ) |>
  summarise(
    first_date = min(event_date),
    last_date = max(event_date),
    number_of_listed_dates = n_distinct(event_date),
    .groups = "drop"
  ) |>
  filter(
    number_of_listed_dates > 1
  ) |>
  arrange(
    desc(number_of_listed_dates)
  )

# Check how many unique events appear on multiple dates
nrow(repeated_event_summary)

# Preview the events that appear on the most dates
repeated_event_summary |>
  head(20)

# Check repeated events that are NOT explicitly labeled as multi-day
repeated_not_labeled_multi_day <- repeated_event_summary |>
  filter(
    !str_detect(
      event_title,
      regex(
        "\\(Multi-Day Event\\)",
        ignore_case = TRUE
      )
    )
  )

# Count these events
nrow(repeated_not_labeled_multi_day)

# Preview them
repeated_not_labeled_multi_day |>
  head(20)



# 6. Check and remove exact duplicate records ----------------------------

# Identify exact duplicate event occurrences.
# A record is considered an exact duplicate only when the same
# event_id, information_id, and event_date appear more than once.
duplicate_summary <- events_no_cancelled |>
  count(
    event_id,
    information_id,
    event_date,
    name = "number_of_records"
  ) |>
  filter(
    number_of_records > 1
  ) |>
  arrange(
    desc(number_of_records)
  )

# Check how many exact duplicate groups exist
nrow(duplicate_summary)


# Preview exact duplicate groups, if any
duplicate_summary |>
  head(20)

# Count how many extra rows are caused by exact duplicates
duplicate_extra_rows <- duplicate_summary |>
  summarise(
    extra_rows = sum(number_of_records - 1)
  ) |>
  pull(extra_rows)
duplicate_extra_rows

# Remove only exact duplicate records
events_clean <- events_no_cancelled |>
  distinct(
    event_id,
    information_id,
    event_date,
    .keep_all = TRUE
  )

# Compare dataset sizes before and after duplicate removal
tibble(
  dataset = c(
    "After removing cancelled events",
    "After removing exact duplicates"
  ),
  number_of_records = c(
    nrow(events_no_cancelled),
    nrow(events_clean)
  )
)

# Confirm that exact duplicates no longer remain
events_clean |>
  count(
    event_id,
    information_id,
    event_date,
    name = "number_of_records"
  ) |>
  filter(
    number_of_records > 1
  )



# 7. Create analysis variables -------------------------------------------

# Identify the date on which the calendar data were scraped
scrape_date <- max(
  events_clean$scraped_at,
  na.rm = TRUE
)
scrape_date

# Create weekday, month, and timing variables
events_clean <- events_clean |>
  mutate(
    
    # Create weekday name from the event date
    weekday = wday(
      event_date,
      label = TRUE,
      abbr = FALSE,
      week_start = 1
    ),
    
    # Make weekday order explicit: Monday through Sunday
    weekday = factor(
      as.character(weekday),
      levels = c(
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ),
      ordered = TRUE
    ),
    
    # Create numeric month
    month_number = month(event_date),
    
    # Create month name
    month_name = month(
      event_date,
      label = TRUE,
      abbr = FALSE
    ),
    
    # Make month order explicit
    month_name = factor(
      as.character(month_name),
      levels = month.name,
      ordered = TRUE
    ),
    
    # Identify whether an event occurs after the scraping date
    is_future_at_scrape = event_date > scrape_date,
    
    # Create a readable timing category
    timing_status = if_else(
      is_future_at_scrape,
      "Scheduled after scrape date",
      "Occurred by scrape date"
    )
  )

# Check the scraping date
scrape_date


# Check weekday values
events_clean |>
  count(
    weekday,
    name = "number_of_records"
  )

# Check month values
events_clean |>
  count(
    month_name,
    name = "number_of_records"
  )

# Check how many records occur before or after the scraping date
events_clean |>
  count(
    timing_status,
    name = "number_of_records"
  )

# Check for missing weekday or month values
events_clean |>
  summarise(
    missing_weekday = sum(is.na(weekday)),
    missing_month = sum(is.na(month_name)),
    missing_timing_status = sum(is.na(timing_status))
  )

# Preview the new variables
events_clean |>
  select(
    event_title,
    event_date,
    weekday,
    month_name,
    timing_status,
    is_multi_day
  ) |>
  head(20)



# 8. Analyze event opportunities by weekday ------------------------------

# Count the number of event occurrences by weekday
weekday_summary <- events_clean |>
  count(
    weekday,
    name = "number_of_events"
  )

# Calculate the number of each weekday in the 2026 calendar
calendar_weekdays <- tibble(
  date = seq.Date(
    from = start_date,
    to = end_date,
    by = "day"
  )
) |>
  mutate(
    weekday = wday(
      date,
      label = TRUE,
      abbr = FALSE,
      week_start = 1
    ),
    
    # Set weekday order from Monday to Sunday
    weekday = factor(
      as.character(weekday),
      levels = c(
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ),
      ordered = TRUE
    )
  ) |>
  count(
    weekday,
    name = "number_of_calendar_days"
  )

# Combine event counts with the number of calendar weekdays
weekday_summary <- weekday_summary |>
  left_join(
    calendar_weekdays,
    by = "weekday"
  ) |>
  mutate(
    
    # Share of all listed event opportunities
    share_of_events = number_of_events /
      sum(number_of_events),
    
    # Average number of listed events for each occurrence
    # of that weekday during 2026
    events_per_weekday = number_of_events /
      number_of_calendar_days
  )

# Display the complete weekday summary
weekday_summary

# Rank weekdays by average event opportunities
weekday_summary_ranked <- weekday_summary |>
  arrange(
    desc(events_per_weekday)
  ) |>
  mutate(
    rank = row_number()
  )

# Display the ranked weekday summary
weekday_summary_ranked

# Create a presentation-friendly summary table
weekday_summary_display <- weekday_summary_ranked |>
  mutate(
    
    # Convert event share to percentage
    share_percent = round(
      share_of_events * 100,
      1
    ),
    
    # Round average events per weekday
    events_per_weekday = round(
      events_per_weekday,
      2
    )
  ) |>
  select(
    rank,
    weekday,
    number_of_events,
    number_of_calendar_days,
    events_per_weekday,
    share_percent
  )

# Display the final presentation-friendly table
weekday_summary_display

# Confirm that all cleaned event records
# are included in the weekday analysis
sum(
  weekday_summary$number_of_events
)
nrow(events_clean)

# Confirm that the presentation table was created
exists("weekday_summary_display")



# 9A. Robustness check: events occurring by the scrape date ---------------

# Keep only events that occurred on or before the scraping date
events_observed <- events_clean |>
  filter(
    event_date <= scrape_date
  )

# Count event occurrences by weekday
weekday_observed <- events_observed |>
  count(
    weekday,
    name = "number_of_events"
  )

# Count how many of each weekday occurred between
# January 1, 2026 and the scrape date
calendar_weekdays_observed <- tibble(
  date = seq.Date(
    from = start_date,
    to = scrape_date,
    by = "day"
  )
) |>
  mutate(
    weekday = wday(
      date,
      label = TRUE,
      abbr = FALSE,
      week_start = 1
    ),
    
    weekday = factor(
      as.character(weekday),
      levels = c(
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ),
      ordered = TRUE
    )
  ) |>
  count(
    weekday,
    name = "number_of_calendar_days"
  )

# Combine counts and calculate events per weekday
weekday_observed <- weekday_observed |>
  left_join(
    calendar_weekdays_observed,
    by = "weekday"
  ) |>
  mutate(
    events_per_weekday =
      number_of_events /
      number_of_calendar_days
  ) |>
  arrange(
    desc(events_per_weekday)
  )

weekday_observed



# 9B. Robustness check: exclude explicitly labeled multi-day events -------

events_without_multi_day <- events_clean |>
  filter(
    !is_multi_day
  )

# Count event occurrences by weekday
weekday_without_multi_day <- events_without_multi_day |>
  count(
    weekday,
    name = "number_of_events"
  ) |>
  left_join(
    calendar_weekdays,
    by = "weekday"
  ) |>
  mutate(
    events_per_weekday =
      number_of_events /
      number_of_calendar_days
  ) |>
  arrange(
    desc(events_per_weekday)
  )

weekday_without_multi_day



# 9C. Compare weekday rankings across specifications ----------------------
weekday_comparison <- weekday_summary |>
  select(
    weekday,
    all_events_per_weekday = events_per_weekday
  ) |>
  left_join(
    weekday_observed |>
      select(
        weekday,
        observed_events_per_weekday = events_per_weekday
      ),
    by = "weekday"
  ) |>
  left_join(
    weekday_without_multi_day |>
      select(
        weekday,
        no_multi_day_events_per_weekday = events_per_weekday
      ),
    by = "weekday"
  ) |>
  mutate(
    across(
      where(is.numeric),
      ~ round(.x, 2)
    )
  )

weekday_comparison



# 10. Create visualizations -----------------------------------------------

# Define the folder for figures
figures_dir <- here(
  "blog",
  "posts",
  "post2",
  "figures"
)

# Create the figures folder if it does not already exist
dir.create(
  figures_dir,
  recursive = TRUE,
  showWarnings = FALSE
)



# 10A. Main figure: event opportunities by weekday ------------------------

weekday_plot <- ggplot(
  weekday_summary,
  aes(
    x = weekday,
    y = events_per_weekday
  )
) +
  geom_col() +
  labs(
    title = "Drexel Events Are Concentrated in the Middle of the Week",
    subtitle = "Average currently listed event opportunities per weekday in 2026",
    x = NULL,
    y = "Average listed events per weekday",
    caption = paste0(
      "Source: Drexel University Events Calendar. ",
      "Data scraped on ",
      format(scrape_date, "%B %d, %Y"),
      "."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(
      face = "bold"
    ),
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )

# Display the figure
weekday_plot

# Save the main figure
ggsave(
  filename = file.path(
    figures_dir,
    "events_by_weekday.png"
  ),
  plot = weekday_plot,
  width = 8,
  height = 5,
  dpi = 300
)
file.exists(
  file.path(
    figures_dir,
    "events_by_weekday.png"
  )
)



# 10B. Robustness comparison figure --------------------------------------

weekday_comparison_long <- weekday_comparison |>
  pivot_longer(
    cols = c(
      all_events_per_weekday,
      observed_events_per_weekday,
      no_multi_day_events_per_weekday
    ),
    names_to = "analysis_type",
    values_to = "events_per_weekday"
  ) |>
  mutate(
    analysis_type = recode(
      analysis_type,
      all_events_per_weekday =
        "All currently listed 2026 events",
      observed_events_per_weekday =
        "Events through September 21",
      no_multi_day_events_per_weekday =
        "Excluding labeled multi-day events"
    )
  )

robustness_plot <- ggplot(
  weekday_comparison_long,
  aes(
    x = weekday,
    y = events_per_weekday,
    group = analysis_type,
    linetype = analysis_type
  )
) +
  geom_line(
    linewidth = 1
  ) +
  geom_point(
    size = 2
  ) +
  labs(
    title = "The Midweek Pattern Is Robust Across Specifications",
    subtitle = "Tuesday and Wednesday consistently have the highest event concentration",
    x = NULL,
    y = "Average event opportunities per weekday",
    linetype = "Analysis",
    caption = paste0(
      "Source: Drexel University Events Calendar. ",
      "Data scraped on ",
      format(scrape_date, "%B %d, %Y"),
      "."
    )
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(
      face = "bold"
    ),
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    legend.position = "bottom"
  )

robustness_plot

ggsave(
  filename = file.path(
    figures_dir,
    "weekday_robustness_check.png"
  ),
  plot = robustness_plot,
  width = 9,
  height = 6,
  dpi = 300
)

file.exists(
  file.path(
    figures_dir,
    "weekday_robustness_check.png"
  )
)



# 11. Save cleaned data and analysis outputs ------------------------------

# Define the folder for processed data
processed_dir <- here(
  "blog",
  "posts",
  "post2",
  "data",
  "processed"
)

# Create the folder if it does not already exist
dir.create(
  processed_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Create the final cleaned event dataset
events_processed <- events_clean |>
  select(
    event_id,
    information_id,
    event_title,
    event_date,
    weekday,
    month_number,
    month_name,
    is_multi_day,
    timing_status,
    event_url,
    source_month,
    scraped_at
  )

# Save the cleaned event dataset
write_csv(
  events_processed,
  file.path(
    processed_dir,
    "drexel_events_clean.csv"
  )
)

# Save the main weekday summary table
write_csv(
  weekday_summary_display,
  file.path(
    processed_dir,
    "weekday_summary.csv"
  )
)

# Save the robustness comparison table
write_csv(
  weekday_comparison,
  file.path(
    processed_dir,
    "weekday_robustness_comparison.csv"
  )
)

# Create monthly counts after cleaning
monthly_counts_clean <- events_processed |>
  count(
    month_name,
    name = "number_of_events"
  )

# Display the monthly counts
monthly_counts_clean

# Save the cleaned monthly counts
write_csv(
  monthly_counts_clean,
  file.path(
    processed_dir,
    "monthly_counts_clean.csv"
  )
)
