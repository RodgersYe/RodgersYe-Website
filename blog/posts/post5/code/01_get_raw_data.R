# Blog 5 | 01: acquire the official 2024 ACS extract.
# Save all four scripts in blog/posts/post5/code/.
# Console: source(here::here("blog", "posts", "post5", "code", "01_get_raw_data.R"))
# Default: reuse local files, resume a saved task, or submit and download once.
# Optional: options(blog5.ipums_stage = "check" / "submit" / "download" / "auto")
# Output: official .xml + .dat.gz; extract_id.txt is resumable API task state.
# No metadata CSV, receipt, session log, or extract-definition JSON is written.

needed <- c("here", "ipumsr")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install: ", paste(missing, collapse = ", "), call. = FALSE)
here::i_am("blog/posts/post5/code/01_get_raw_data.R")

run_blog5_download <- function() {
  raw_dir <- here::here("blog", "posts", "post5", "data", "raw", "ipums_2024")
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  id_path <- file.path(raw_dir, "extract_id.txt")
  stage <- getOption("blog5.ipums_stage", "auto")
  if (length(stage) != 1L || !stage %in% c("auto", "check", "submit", "download")) {
    stop("blog5.ipums_stage must be auto, check, submit, or download.", call. = FALSE)
  }

  # Protect local credentials and household microdata in the public repository.
  ignore_path <- here::here(".gitignore")
  old <- if (file.exists(ignore_path)) readLines(ignore_path, warn = FALSE) else character()
  rules <- c(".Renviron", ".Renviron.*", ".Rhistory", ".RData",
             "/blog/posts/post5/data/raw/ipums_2024/",
             "/blog/posts/post5/data/processed/single_person_renters_clean.rds")
  new <- setdiff(rules, old)
  if (length(new)) cat("\n", paste(new, collapse = "\n"), "\n",
                       file = ignore_path, append = TRUE, sep = "")

  xml <- list.files(raw_dir, pattern = "^usa_[0-9]+\\.xml$", full.names = TRUE)
  paired <- xml[file.exists(sub("\\.xml$", ".dat.gz", xml))]
  if (length(paired) > 1L) stop("Keep only the intended extract pair in raw_dir.", call. = FALSE)
  if (length(paired) == 1L && stage != "check") {
    files <- c(paired, sub("\\.xml$", ".dat.gz", paired))
    if (any(file.info(files)$size <= 0)) stop("A local raw file is empty.", call. = FALSE)
    message("Using existing raw files: ", paste(basename(files), collapse = ", "))
    message("No API request made. Next: 02_clean_data.R.")
    return(invisible(files))
  }
  if (length(xml) && !length(paired)) {
    stop("An incomplete extract exists. Preserve it and resolve the missing data file before retrying.",
         call. = FALSE)
  }
  orphan_data <- list.files(raw_dir, pattern = "^usa_[0-9]+\\.dat\\.gz$", full.names = TRUE)
  if (length(orphan_data) && !length(paired)) {
    stop("A raw data file lacks its XML. Restore its codebook before requesting another extract.", call. = FALSE)
  }
  if (!nzchar(trimws(Sys.getenv("IPUMS_API_KEY")))) {
    env_path <- here::here(".Renviron")
    if (file.exists(env_path)) readRenviron(env_path)
  }
  if (!nzchar(trimws(Sys.getenv("IPUMS_API_KEY")))) {
    stop("Set IPUMS_API_KEY in the local .Renviron; do not put the key in code.", call. = FALSE)
  }
  variables <- c(
    "YEAR", "SAMPLE", "SERIAL", "PERNUM", "STATEFIP", "GQ", "NUMPREC",
    "AGE", "INCTOT", "HHINCOME", "OWNERSHP", "RENT", "RENTGRS",
    "HHWT", "PERWT", "ADJUST", "INCWAGE", "INCBUS00", "INCINVST", "INCSS",
    "INCRETIR", "INCWELFR", "INCSUPP", "INCOTHER", "COSTELEC", "COSTGAS",
    "COSTFUEL", "COSTWATR", "REPWT"
  )
  # Keep the original specification so existing and new extracts are comparable.
  # OWNERSHP also supplies its detailed OWNERSHPD variable; REPWT supplies 1:80.
  specification <- ipumsr::define_extract_micro(
    collection = "usa", samples = "us2024a", variables = variables,
    description = "Blog 5: 2024 ACS single-person renter affordability; complete household members",
    data_format = "fixed_width", data_structure = "rectangular",
    rectangular_on = "P", data_quality_flags = TRUE
  )
  if (stage == "check") {
    samples <- ipumsr::get_sample_info(collection = "usa")
    selected <- Reduce(`|`, lapply(samples, function(x) !is.na(x) & as.character(x) == "us2024a"))
    if (sum(selected) != 1L) stop("Could not identify us2024a uniquely.", call. = FALSE)
    print(samples[selected, , drop = FALSE], width = Inf)
    print(specification)
    message("Check complete. Nothing submitted or downloaded.")
    return(invisible(specification))
  }
  if (stage == "submit" && file.exists(id_path)) {
    stop("A task is already saved. Use stage auto or download.", call. = FALSE)
  }
  if (!file.exists(id_path)) {
    if (stage == "download") stop("No saved extract_id.txt; run auto or submit first.", call. = FALSE)
    submitted <- ipumsr::submit_extract(specification)
    extract_id <- paste0("usa:", submitted$number)
    # Save immediately so a later timeout never causes an automatic resubmission.
    writeLines(extract_id, id_path)
    message("Submitted and saved task: ", extract_id)
    if (stage == "submit") return(invisible(extract_id))
  }
  extract_id <- trimws(readLines(id_path, warn = FALSE))
  if (length(extract_id) != 1L || !grepl("^usa:[0-9]+$", extract_id)) {
    stop("Invalid extract_id.txt.", call. = FALSE)
  }
  ready <- ipumsr::wait_for_extract(extract_id, max_delay_seconds = 30,
                                   timeout_seconds = 1800, verbose = TRUE)
  if (!ipumsr::is_extract_ready(ready)) {
    stop("Task is not ready. Resume download later; do not submit a duplicate task.", call. = FALSE)
  }
  ddi_path <- ipumsr::download_extract(ready, download_dir = raw_dir,
                                     overwrite = FALSE, progress = TRUE)
  files <- c(ddi_path, sub("\\.xml$", ".dat.gz", ddi_path))
  if (length(files) != 2L || !all(file.exists(files)) || any(file.info(files)$size <= 0)) {
    stop("Expected both a nonempty DDI and .dat.gz file.", call. = FALSE)
  }
  message("Raw download complete. Next: 02_clean_data.R.")
  invisible(files)
}

run_blog5_download()
