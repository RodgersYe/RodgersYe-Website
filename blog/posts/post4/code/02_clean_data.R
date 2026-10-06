# Blog Post 4 — 02_clean_data.R
# Clean and merge 2024 BEA series for the 50 U.S. states.
# Use the September 26, 2025 archived SAINC1 income vintage.
# Keep the later API income vintage for a revision audit only.

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the 'here' package first: install.packages('here')")
}

raw_dir <- here::here(
  "blog", "posts", "post4", "data", "raw"
)

processed_dir <- here::here(
  "blog", "posts", "post4", "data", "processed"
)

year <- "2024"

# Read one previously saved BEA API series.
read_bea_series <- function(filename, expected_unit) {
  path <- file.path(raw_dir, filename)
  
  if (!file.exists(path)) {
    stop("Missing raw file: ", path)
  }
  
  x <- utils::read.csv(
    path,
    colClasses = c(GeoFips = "character"),
    stringsAsFactors = FALSE
  )
  
  required <- c(
    "GeoFips", "GeoName", "TimePeriod",
    "DataValue", "CL_UNIT"
  )
  
  if (!all(required %in% names(x))) {
    stop("Required BEA columns are missing from ", filename)
  }
  
  if (
    anyDuplicated(x[c("GeoFips", "TimePeriod")]) > 0 ||
    !all(as.character(x$TimePeriod) == year)
  ) {
    stop("Duplicate geographies or unexpected years in ", filename)
  }
  
  if (!all(x$CL_UNIT == expected_unit)) {
    stop("Unexpected unit in ", filename)
  }
  
  x$state <- sub(
    "\\s*\\*+$",
    "",
    trimws(as.character(x$GeoName))
  )
  
  x$value <- suppressWarnings(as.numeric(
    gsub(",", "", as.character(x$DataValue), fixed = TRUE)
  ))
  
  if (any(!is.finite(x$value)) || any(x$value <= 0)) {
    stop("Missing, nonnumeric, or nonpositive values in ", filename)
  }
  
  x
}

# Read 2024 PCPI from BEA's archived September 26, 2025 ZIP.
read_archived_pcpi <- function() {
  filename <- "bea_state_annual_income_2025-09-26.zip"
  path <- file.path(raw_dir, filename)
  entry <- "SAINC1__ALL_AREAS_1929_2024.csv"
  
  if (!file.exists(path)) {
    stop("Missing archived BEA ZIP: ", path)
  }
  
  contents <- utils::unzip(path, list = TRUE)$Name
  
  if (sum(contents == entry) != 1) {
    stop("The archived ZIP does not contain exactly one ", entry)
  }
  
  archive <- utils::read.csv(
    unz(path, entry),
    colClasses = "character",
    check.names = FALSE,
    strip.white = TRUE,
    stringsAsFactors = FALSE
  )
  
  required <- c(
    "GeoFIPS", "GeoName", "TableName",
    "LineCode", "Unit", year
  )
  
  if (!all(required %in% names(archive))) {
    stop("Required SAINC1 columns are missing from the archived ZIP.")
  }
  
  x <- archive[
    archive$TableName == "SAINC1" &
      archive$LineCode == "3",
  ]
  
  if (
    nrow(x) < 52 ||
    anyDuplicated(x$GeoFIPS) > 0 ||
    anyNA(x$GeoFIPS) ||
    !all(x$Unit == "Dollars")
  ) {
    stop(
      "Archived SAINC1 line 3 failed its geography or unit checks."
    )
  }
  
  x$state <- sub(
    "\\s*\\*+$",
    "",
    trimws(as.character(x$GeoName))
  )
  
  x$value <- suppressWarnings(as.numeric(
    gsub(",", "", x[[year]], fixed = TRUE)
  ))
  
  if (any(!is.finite(x$value)) || any(x$value <= 0)) {
    stop("Archived SAINC1 has invalid 2024 PCPI values.")
  }
  
  data.frame(
    GeoFips = x$GeoFIPS,
    GeoName = x$GeoName,
    TimePeriod = year,
    state = x$state,
    value = x$value,
    stringsAsFactors = FALSE
  )
}

# Main income series: fixed historical release.
nominal_raw <- read_archived_pcpi()

# Later API income release: retained only to audit revisions.
api_nominal_raw <- read_bea_series(
  "bea_nominal_pcpi_2024.csv",
  "Dollars"
)

rpp_raw <- read_bea_series(
  "bea_all_items_rpp_2024.csv",
  "Index"
)

real_raw <- read_bea_series(
  "bea_official_real_pcpi_2024.csv",
  "Constant 2017 dollars"
)

# Define the study sample using BEA's state RPP series.
# Exclude the U.S. total and the District of Columbia.
if (!all(c("00000", "11000") %in% rpp_raw$GeoFips)) {
  stop("The expected U.S. total or D.C. row is missing.")
}

rpp_state_rows <- rpp_raw[
  !rpp_raw$GeoFips %in% c("00000", "11000"),
]

state_ids <- rpp_state_rows$GeoFips

if (
  length(state_ids) != 50 ||
  anyDuplicated(state_ids) > 0 ||
  !setequal(rpp_state_rows$state, state.name)
) {
  stop(
    "The RPP data do not match the expected 50 states. ",
    "Inspect GeoFips and GeoName before continuing."
  )
}

# Each source must contain the same 50 state codes.
sources <- list(
  "archived nominal" = nominal_raw,
  "later API nominal" = api_nominal_raw,
  "RPP" = rpp_raw,
  "official real" = real_raw
)

for (source_name in names(sources)) {
  available_ids <- sources[[source_name]]$GeoFips[
    sources[[source_name]]$GeoFips %in% state_ids
  ]
  
  if (!setequal(available_ids, state_ids)) {
    stop(
      "The ", source_name,
      " series is missing one or more states."
    )
  }
}

make_state_table <- function(x, value_name) {
  x <- x[x$GeoFips %in% state_ids, ]
  
  out <- data.frame(
    GeoFips = x$GeoFips,
    state = x$state,
    year = as.character(x$TimePeriod),
    value = x$value,
    stringsAsFactors = FALSE
  )
  
  names(out)[names(out) == "value"] <- value_name
  out
}

nominal <- make_state_table(nominal_raw, "nominal_pcpi")
rpp <- make_state_table(rpp_raw, "rpp_all_items")
official_real <- make_state_table(
  real_raw,
  "official_real_pcpi"
)

state_data <- merge(
  nominal,
  rpp,
  by = c("GeoFips", "state", "year")
)

state_data <- merge(
  state_data,
  official_real,
  by = c("GeoFips", "state", "year")
)

if (
  nrow(state_data) != 50 ||
  !setequal(state_data$GeoFips, state_ids) ||
  anyNA(state_data) ||
  anyDuplicated(state_data[c("GeoFips", "year")]) > 0
) {
  stop(
    "The merged data failed validation. ",
    "Check state names and geographic codes across the sources."
  )
}

state_data <- state_data[
  order(state_data$state),
  c(
    "GeoFips", "state", "year",
    "nominal_pcpi", "rpp_all_items",
    "official_real_pcpi"
  )
]

# Audit how much the later API income release revised 2024 PCPI.
api_nominal_states <- make_state_table(
  api_nominal_raw,
  "api_nominal_pcpi"
)

api_values <- api_nominal_states$api_nominal_pcpi[
  match(state_data$GeoFips, api_nominal_states$GeoFips)
]

if (anyNA(api_values)) {
  stop("Could not match later API PCPI to all 50 states.")
}

revision <- api_values - state_data$nominal_pcpi

dir.create(
  processed_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

output_path <- file.path(
  processed_dir,
  "state_income_prices_2024.csv"
)

utils::write.csv(
  state_data,
  file = output_path,
  row.names = FALSE
)

excluded_nominal <- nominal_raw[
  !nominal_raw$GeoFips %in% state_ids,
  c("GeoFips", "GeoName")
]

cat("Processed state rows:", nrow(state_data), "\n")
cat("Year:", paste(unique(state_data$year), collapse = ", "), "\n")
cat("Nominal PCPI source: archived SAINC1, line 3,",
    "September 26, 2025 release.\n")
cat("States revised in later API income data:",
    sum(revision != 0), "\n")
cat("Largest absolute PCPI revision:",
    max(abs(revision)), "dollars\n")
cat("Excluded rows from the archived nominal-income file:\n")
print(excluded_nominal, row.names = FALSE)
cat("Saved:", output_path, "\n")