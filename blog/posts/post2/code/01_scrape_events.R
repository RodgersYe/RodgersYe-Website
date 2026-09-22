# ============================================================
# Blog Post 2
# Web Scraping Drexel University Events Calendar
#
# Research Question:
# Which day or days of the week offer the most opportunities
# for attending events listed on the Drexel University
# Events Calendar?
#
# Research Period:
# October 1, 2026 - September 30, 2027
# ============================================================


# 1. Load packages --------------------------------------------------------

library(rvest)
library(tidyverse)
library(lubridate)
library(here)
library(robotstxt)



# 2. Define research period and website ----------------------------------

# Define the research period
start_date <- ymd("2026-01-01")
end_date   <- ymd("2026-12-31")


# Drexel University Events Calendar
drexel_domain <- "calendar.drexel.edu"
drexel_base <- "https://calendar.drexel.edu/EventList.aspx"


# Create a test URL for January 2026
test_url <- paste0(
  drexel_base,
  "?fromdate=01/01/2026",
  "&todate=01/31/2026",
  "&display=Month",
  "&type=public",
  "&view=DateTime"
)


# Check the variables
start_date
end_date
test_url



# 3. Check robots.txt -----------------------------------------------------

robots_check <- paths_allowed(
  paths = "/EventList.aspx",
  domain = drexel_domain
)

print(robots_check)



# 4. Test connection to the calendar -------------------------------------

test_page <- read_html(test_url)
test_page

test_text <- test_page |>
  html_text2()
substr(test_text, 1, 3000)



# 5. Test extraction of event information -------------------------------

# Extract all event links from the January 2026 calendar page
test_event_links <- test_page |>
  html_elements("a[href*='view=EventDetails']")

# Check how many event links were found
length(test_event_links)

# Preview the first 10 event titles
test_event_links |>
  html_text2() |>
  head(10)

# Preview the first 10 event URLs
test_event_links |>
  html_attr("href") |>
  head(10)

# Extract all table rows
test_rows <- test_page |>
  html_elements("tr")

# Convert each row to text
test_row_text <- test_rows |>
  html_text2() |>
  str_squish()

# Define the date pattern for October 2026
date_pattern <- paste0(
  "^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\\s+",
  "January\\s+\\d{2},\\s+2026$"
)

# Preview the first 20 date-header rows
tibble(
  row_number = seq_along(test_row_text),
  text = test_row_text
) |>
  filter(
    str_detect(
      text,
      date_pattern
    )
  ) |>
  head(20)



# 6. Define general date pattern -----------------------------------------

date_pattern <- paste0(
  "^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\\s+",
  "(January|February|March|April|May|June|July|August|September|October|November|December)\\s+",
  "\\d{1,2},\\s+\\d{4}$"
)

# Test the general date pattern
tibble(
  row_number = seq_along(test_row_text),
  text = test_row_text
) |>
  filter(
    str_detect(
      text,
      date_pattern
    )
  ) |>
  head(35)



# 7. Create scrape_month() function --------------------------------------

scrape_month <- function(month_start) {
  
  # Make sure the input is the first day of the month
  month_start <- floor_date(month_start, "month")
  
  # Calculate the last day of the month
  month_end <- ceiling_date(
    month_start,
    "month"
  ) - days(1)
  
  # Build the monthly calendar URL
  month_url <- paste0(
    drexel_base,
    "?fromdate=",
    format(month_start, "%m/%d/%Y"),
    "&todate=",
    format(month_end, "%m/%d/%Y"),
    "&display=Month",
    "&type=public",
    "&view=DateTime"
  )
  
  # Show scraping progress in the Console
  message(
    "Scraping ",
    format(month_start, "%B %Y")
  )
  
  # Read the calendar page
  page <- read_html(month_url)
  
  # Extract all table rows
  rows <- page |>
    html_elements("tr")
  
  # Convert each row to plain text
  row_text <- rows |>
    html_text2() |>
    str_squish()
  
  # Extract event links from each row
  event_href <- map_chr(
    rows,
    function(row) {
      
      links <- row |>
        html_elements(
          "a[href*='view=EventDetails']"
        ) |>
        html_attr("href")
      
      if (length(links) == 0) {
        return(NA_character_)
      }
      links[[1]]
    }
  )
  
  # Extract event titles from each row
  event_title <- map_chr(
    rows,
    function(row) {
      titles <- row |>
        html_elements(
          "a[href*='view=EventDetails']"
        ) |>
        html_text2()
      if (length(titles) == 0) {
        return(NA_character_)
      }
      str_squish(titles[[1]])
    }
  )

  # Identify rows that contain a date header
  date_text <- if_else(
    str_detect(
      row_text,
      date_pattern
    ),
    row_text,
    NA_character_
  )

  # Build the monthly dataset
  month_data <- tibble(
    row_number = seq_along(rows),
    date_text = date_text,
    event_title = event_title,
    event_href = event_href,
    row_text = row_text
  ) |>
    
    # Carry each date downward to the event rows below it
    fill(date_text) |>
    
    # Keep only rows that contain actual events
    filter(!is.na(event_href)) |>
    
    # Convert the date text into R Date format
    mutate(
      event_date = mdy(
        str_remove(
          date_text,
          "^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\\s+"
        )
      )
    ) |>
    
    # Create the full event URL
    mutate(
      event_url = xml2::url_absolute(
        event_href,
        drexel_base
      )
    ) |>
    
    # Extract event identifiers from the URL
    mutate(
      event_id = str_extract(
        event_href,
        "(?<=eventidn=)\\d+"
      ),
      information_id = str_extract(
        event_href,
        "(?<=information_id=)\\d+"
      )
    ) |>
    
    # Record the source month and scraping date
    mutate(
      source_month = month_start,
      scraped_at = Sys.Date()
    ) |>
    
    # Keep only the variables needed for the raw dataset
    select(
      event_id,
      information_id,
      event_title,
      event_date,
      row_text,
      event_url,
      source_month,
      scraped_at
    )

  # Return the finished monthly dataset
  return(month_data)
}



# 8. Test scrape_month() function ----------------------------------------

# Scrape January 2026 as a test month
test_month <- scrape_month(
  ymd("2026-01-01")
)

# Open the dataset in the RStudio Data Viewer
View(test_month)

# Check the structure of the dataset
glimpse(test_month)

# Preview the first 20 rows
head(test_month, 20)

# Check the date range
range(
  test_month$event_date,
  na.rm = TRUE
)

# Check whether any event dates are missing
test_month |>
  filter(is.na(event_date))

# Check whether any event titles are missing
test_month |>
  filter(is.na(event_title))


# Check how many event records were scraped
nrow(test_month)



# 9. Create list of months -----------------------------------------------

month_starts <- seq.Date(
  from = floor_date(start_date, "month"),
  to   = floor_date(end_date, "month"),
  by   = "month"
)

# Check the list of months
month_starts

# Confirm that there are 12 months
length(month_starts)



# 10. Scrape all 12 months -----------------------------------------------

all_months <- map(
  month_starts,
  function(month_start) {
    # Scrape one month
    month_data <- scrape_month(month_start)
    # Pause between requests to reduce server load
    Sys.sleep(2.0)
    # Return the monthly dataset
    return(month_data)
  }
)

# Confirm that 12 monthly datasets were created
length(all_months)
map_int(all_months, nrow)



# 11. Combine and inspect raw data ----------------------------------------

# Combine the 12 monthly datasets into one dataset
raw_events <- bind_rows(all_months)

# Check the structure of the combined dataset
glimpse(raw_events)

# Check the total number of event records
nrow(raw_events)

# Check the overall date range
range(
  raw_events$event_date,
  na.rm = TRUE
)

# Check for missing values in important variables
raw_events |>
  summarise(
    missing_event_id = sum(is.na(event_id)),
    missing_information_id = sum(is.na(information_id)),
    missing_event_title = sum(is.na(event_title)),
    missing_event_date = sum(is.na(event_date)),
    missing_event_url = sum(is.na(event_url))
  )

# Count the number of event records by month
monthly_counts <- raw_events |>
  count(
    source_month,
    name = "number_of_events"
  )
monthly_counts
map_int(all_months, nrow)



# 12. Save raw data -------------------------------------------------------

# Save the complete raw dataset
write_csv(
  raw_events,
  here(
    "blog",
    "posts",
    "post2",
    "data",
    "raw",
    "drexel_events_raw.csv"
  )
)

# Check that the file was successfully created
raw_file_path <- here(
  "blog",
  "posts",
  "post2",
  "data",
  "raw",
  "drexel_events_raw.csv"
)
file.exists(raw_file_path)

# Display the saved file path
raw_file_path