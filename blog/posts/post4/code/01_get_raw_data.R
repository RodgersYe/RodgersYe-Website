# Blog Post 4 — 01_get_raw_data.R
# Download 2024 state-level BEA data without saving the API key.
# Run from the website's RStudio Project.

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the 'here' package first: install.packages('here')")
}
if (!requireNamespace("httr2", quietly = TRUE)) {
  stop("Install the 'httr2' package first: install.packages('httr2')")
}

api_key <- Sys.getenv("BEA_API_KEY", unset = "")
if (!nzchar(api_key)) {
  stop(
    "BEA_API_KEY is missing. Set it in the project-level .Renviron ",
    "and restart the R session."
  )
}

year <- "2024"

raw_dir <- here::here(
  "blog", "posts", "post4", "data", "raw"
)
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

series <- list(
  nominal_pcpi = list(table = "SAINC1", line = 3),
  all_items_rpp = list(table = "SARPP", line = 1),
  official_real_pcpi = list(table = "SARPI", line = 2)
)

get_bea_data <- function(table, line, year, api_key) {
  response <- tryCatch(
    httr2::request("https://apps.bea.gov/api/data/") |>
      httr2::req_url_query(
        UserID = api_key,
        method = "GetData",
        datasetname = "Regional",
        TableName = table,
        LineCode = line,
        GeoFips = "STATE",
        Year = year,
        ResultFormat = "JSON"
      ) |>
      httr2::req_timeout(30) |>
      httr2::req_perform(),
    error = function(e) {
      stop(
        "BEA request failed for ", table, " line ", line,
        ". Check the connection and API status. ",
        "Do not share a request URL containing your key.",
        call. = FALSE
      )
    }
  )
  
  result <- httr2::resp_body_json(
    response,
    simplifyVector = TRUE
  )$BEAAPI$Results
  
  rows <- result$Data
  required_columns <- c(
    "GeoFips", "GeoName", "TimePeriod", "DataValue"
  )
  
  if (
    !is.data.frame(rows) ||
    nrow(rows) == 0 ||
    !all(required_columns %in% names(rows))
  ) {
    stop(
      "BEA returned no usable data for ",
      table, " line ", line, ".",
      call. = FALSE
    )
  }
  
  if (!all(as.character(rows$TimePeriod) == year)) {
    stop(
      "Unexpected year in BEA data for ", table,
      " line ", line, ".",
      call. = FALSE
    )
  }
  
  metadata <- list(
    table = table,
    line = line,
    year = year,
    statistic = result$Statistic,
    unit_of_measure = result$UnitOfMeasure,
    public_table = result$PublicTable,
    production_time_utc = result$UTCProductionTime,
    notes = result$Notes
  )
  
  list(data = rows, metadata = metadata)
}

# Finish all three requests before writing any files.
downloads <- lapply(
  series,
  function(item) {
    get_bea_data(
      table = item$table,
      line = item$line,
      year = year,
      api_key = api_key
    )
  }
)

for (name in names(downloads)) {
  output_file <- file.path(
    raw_dir,
    paste0("bea_", name, "_", year, ".csv")
  )
  
  utils::write.csv(
    downloads[[name]]$data,
    file = output_file,
    row.names = FALSE,
    na = ""
  )
  
  cat(
    name, ": ",
    nrow(downloads[[name]]$data),
    " raw rows; unit = ",
    downloads[[name]]$metadata$unit_of_measure,
    "\n",
    sep = ""
  )
}

# Store selected BEA metadata and footnotes, never the full API response.
# The full response can echo UserID, which must not enter the repository.
safe_metadata <- lapply(downloads, `[[`, "metadata")
safe_metadata$retrieved_at_utc <- format(
  Sys.time(),
  tz = "UTC",
  usetz = TRUE
)

saveRDS(
  safe_metadata,
  file = file.path(raw_dir, "bea_2024_metadata.rds")
)

cat("Raw BEA data saved in:", raw_dir, "\n")