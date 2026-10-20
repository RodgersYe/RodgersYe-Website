# Blog 5 | 02: filter and transform; write ONE processed dataset.
# Console: source(here::here("blog", "posts", "post5", "code", "02_clean_data.R"))
# Output: data/processed/single_person_renters_clean.rds
# The one RDS contains 50 states AND DC, distinguished by study_scope.
# No CSV copy, DC file, diagnostic directory, or validation report is written.
# Full substantive validation is performed once in 03_analyze_data.R.

needed <- c("here", "ipumsr", "data.table", "tidyselect")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install: ", paste(missing, collapse = ", "), call. = FALSE)
suppressPackageStartupMessages(library(data.table))
here::i_am("blog/posts/post5/code/02_clean_data.R")

run_blog5_cleaning <- function() {
  post_dir <- here::here("blog", "posts", "post5")
  raw_dir <- file.path(post_dir, "data", "raw", "ipums_2024")
  out_dir <- file.path(post_dir, "data", "processed")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  xml <- list.files(raw_dir, pattern = "^usa_[0-9]+\\.xml$", full.names = TRUE)
  xml <- xml[file.exists(sub("\\.xml$", ".dat.gz", xml))]
  if (length(xml) != 1L) stop("Expected one official XML/.dat.gz pair in ", raw_dir, call. = FALSE)
  data_path <- sub("\\.xml$", ".dat.gz", xml)
  ddi <- ipumsr::read_ipums_ddi(xml)
  available <- ipumsr::ipums_var_info(ddi)$var_name
  reps <- paste0("REPWT", 1:80)
  core <- c("YEAR", "SAMPLE", "SERIAL", "PERNUM", "STATEFIP", "GQ", "NUMPREC",
            "AGE", "OWNERSHPD", "INCTOT", "HHINCOME", "RENT", "RENTGRS",
            "HHWT", "PERWT", "ADJUST", reps)
  absent <- setdiff(core, available)
  if (length(absent)) stop("Cannot clean: required DDI fields absent: ",
                           paste(absent, collapse = ", "), call. = FALSE)
  flags <- grep("^Q", available, value = TRUE)
  selected <- c(core, flags)
  fips50 <- c(1,2,4,5,6,8,9,10,12,13,15,16,17,18,19,20,21,22,23,24,25,
              26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,
              46,47,48,49,50,51,53,54,55,56)
  state_map <- data.table(STATEFIP = c(fips50, 11),
                          state_name = c(state.name, "District of Columbia"),
                          state_abbr = c(state.abb, "DC"))
  chunks <- list()
  n_read <- 0
  callback <- function(x, pos) {
    d <- as.data.table(x)
    n_read <<- n_read + nrow(d)
    # No gender, marital-status, employment, bedroom or building-type restriction.
    keep <- d[GQ %in% c(1,2) & NUMPREC == 1 & PERNUM == 1 &
                is.finite(AGE) & AGE >= 18 & AGE != 999 &
                STATEFIP %in% c(fips50, 11) & OWNERSHPD == 22 &
                is.finite(RENTGRS) & RENTGRS > 0 & is.finite(HHWT) & HHWT > 0]
    if (nrow(keep)) chunks[[length(chunks) + 1L]] <<- keep
    if (n_read %% 500000 == 0) message("Read ", format(n_read, big.mark = ","), " records...")
    invisible(NULL)
  }
  ipumsr::read_ipums_micro_chunked(ddi, callback = callback,
    chunk_size = 100000, vars = tidyselect::all_of(selected), data_file = data_path,
    var_attrs = NULL, verbose = FALSE)
  if (!length(chunks)) stop("No records meet the study filters.", call. = FALSE)
  d <- rbindlist(chunks, use.names = TRUE)
  rm(chunks)
  d[, income_status := fcase(
    !is.finite(INCTOT), "missing", INCTOT == 9999999, "not_in_universe",
    INCTOT == 9999998, "unknown", INCTOT == 1, "one_dollar_or_break_even",
    INCTOT == 0, "zero", INCTOT < 0, "negative", default = "positive")]
  d[, annual_income := as.numeric(INCTOT)]
  d[!income_status %in% c("positive", "zero", "negative"), annual_income := NA_real_]
  d[, annual_household_income := as.numeric(HHINCOME)]
  d[!is.finite(HHINCOME) | HHINCOME == 9999999, annual_household_income := NA_real_]
  # ipumsr has already applied DDI implied decimals. No ADJUST multiplication.
  d[, `:=`(monthly_gross_rent = as.numeric(RENTGRS),
            annualized_gross_rent = 12 * as.numeric(RENTGRS),
            ratio_eligible = is.finite(annual_income) & annual_income > 0,
            age_group = fifelse(AGE < 65, "18-64", "65+"),
            study_scope = fifelse(STATEFIP == 11, "DC_separate", "main_50_states"),
            state_name = state_map$state_name[match(STATEFIP, state_map$STATEFIP)],
            state_abbr = state_map$state_abbr[match(STATEFIP, state_map$STATEFIP)],
            household_id = paste(SAMPLE, SERIAL, sep = "_"))]
  setorder(d, STATEFIP, SAMPLE, SERIAL)
  # Lineage lives inside the dataset, not in separate verification files.
  attr(d, "blog5_metadata") <- list(
    schema_version = 2L, sample_id = "us2024a", sample_code = 202401L,
    source_files = data.frame(file = basename(c(xml, data_path)),
                              md5 = unname(tools::md5sum(c(xml, data_path)))),
    raw_person_records = n_read,
    cleaned_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    ipumsr_version = as.character(utils::packageVersion("ipumsr")),
    main_weight = "HHWT", monetary_adjustment = "none")

  ignore_path <- here::here(".gitignore")
  old <- if (file.exists(ignore_path)) readLines(ignore_path, warn = FALSE) else character()
  rule <- "/blog/posts/post5/data/processed/single_person_renters_clean.rds"
  if (!rule %in% old) cat("\n", rule, "\n", file = ignore_path, append = TRUE, sep = "")
  path <- file.path(out_dir, "single_person_renters_clean.rds")
  saveRDS(d, path, compress = "gzip")
  message("Saved ONE processed dataset: ", path)
  message("50-state records: ", sum(d$study_scope == "main_50_states"),
          "; DC records: ", sum(d$study_scope == "DC_separate"))
  message("Next: 03_analyze_data.R performs validation and writes exactly two CSV reports.")
  invisible(path)
}

run_blog5_cleaning()
