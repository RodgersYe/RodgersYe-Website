# Blog 5 | 03: ONE consolidated validation + ONE statistical summary.
# Console: source(here::here("blog", "posts", "post5", "code", "03_analyze_data.R"))
# Inputs: official raw pair + the single RDS from the NEW 02 script.
# Outputs, both in data/processed/:
#   data_validation_report.csv  (checks, counts, codes, PASS/FAIL/WARN/INFO)
#   statistical_summary.csv     (tidy estimates; states, US50, DC, age domains)
# No narrative interpretation, TXT reports, metadata files, or separate tables.
# The raw data are read once here to verify complete household membership,
# source lineage, filtering, original values and DDI implied-decimal parsing.
# Existing old diagnostics are neither read nor deleted.
# Population context is aggregated from the full raw person file in the same
# validation pass: all ages/tenures, with group quarters in the denominator.
# Living alone: GQ in {1,2}, NUMPREC=1, PERNUM=1. Population shares use PERWT.
# Sample-record shares are retained separately. No new dataset is exported.

needed <- c("here", "ipumsr", "data.table", "tidyselect")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install: ", paste(missing, collapse = ", "), call. = FALSE)
suppressPackageStartupMessages(library(data.table))
here::i_am("blog/posts/post5/code/03_analyze_data.R")

run_blog5_analysis <- function() {
  post_dir <- here::here("blog", "posts", "post5")
  out_dir <- file.path(post_dir, "data", "processed")
  raw_dir <- file.path(post_dir, "data", "raw", "ipums_2024")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  clean_path <- file.path(out_dir, "single_person_renters_clean.rds")
  validation_path <- file.path(out_dir, "data_validation_report.csv")
  summary_path <- file.path(out_dir, "statistical_summary.csv")
  run_id <- format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC")
  report <- list()
  add <- function(section, check, observed = NA_character_, expected = NA_character_,
                  n_checked = NA_real_, n_failures = NA_real_, weighted_n = NA_real_,
                  status = "INFO", severity = "info", geography = "all", state_fips = NA_character_,
                  age_scope = "all_adults", variable = NA_character_) {
    report[[length(report) + 1L]] <<- data.table(
      run_id = run_id, section = section, geography = geography,
      state_fips = as.character(state_fips), age_scope = age_scope, variable = variable,
      check = check, observed = as.character(observed), expected = as.character(expected),
      n_checked = as.numeric(n_checked), n_failures = as.numeric(n_failures),
      weighted_n = as.numeric(weighted_n), status = status, severity = severity)
  }
  test <- function(section, check, failures, n_checked = NA_real_, variable = NA_character_,
                   geography = "all", state_fips = NA_character_, severity = "error") {
    ok <- is.finite(failures) && failures == 0
    add(section, check, observed = failures, expected = 0, n_checked = n_checked,
        n_failures = failures, variable = variable, geography = geography,
        state_fips = state_fips, severity = severity,
        status = if (ok) "PASS" else if (severity == "error") "FAIL" else "WARN")
  }
  write_report <- function() {
    if (length(report)) fwrite(rbindlist(report, use.names = TRUE, fill = TRUE),
                              validation_path, na = "NA")
  }
  # A failed run leaves this one report, but no completion marker for 04.
  on.exit(write_report(), add = TRUE)
  gate <- function() {
    write_report()
    if (any(vapply(report, function(x) any(x$status == "FAIL"), logical(1)))) {
      stop("Validation failed; inspect data_validation_report.csv. Statistical output was not refreshed.",
           call. = FALSE)
    }
  }
  test("input", "processed_file_exists", as.integer(!file.exists(clean_path)))
  gate()
  obj <- readRDS(clean_path)
  metadata <- attr(obj, "blog5_metadata")
  test("schema", "table_class", as.integer(!is.data.frame(obj)))
  test("schema", "schema_version_2", as.integer(!identical(metadata$schema_version, 2L)))
  gate()
  d <- as.data.table(obj)
  rm(obj)
  process_md5 <- unname(tools::md5sum(clean_path))
  add("input", "processed_md5", observed = process_md5, variable = basename(clean_path))
  reps <- paste0("REPWT", 1:80)
  raw_core <- c("YEAR", "SAMPLE", "SERIAL", "PERNUM", "NUMPREC", "GQ", "AGE",
                "OWNERSHPD", "STATEFIP", "INCTOT", "HHINCOME", "RENT", "RENTGRS",
                "HHWT", "PERWT", "ADJUST")
  derived <- c("household_id", "state_name", "state_abbr", "study_scope", "age_group",
               "income_status", "annual_income", "annual_household_income",
               "monthly_gross_rent", "annualized_gross_rent", "ratio_eligible")
  required <- c(raw_core, reps, derived)
  test("schema", "missing_columns", length(setdiff(required, names(d))))
  test("schema", "nonempty_dataset", as.integer(nrow(d) == 0))
  gate()
  numeric_fields <- c(raw_core, reps, "annual_income", "annual_household_income",
                      "monthly_gross_rent", "annualized_gross_rent")
  test("schema", "nonnumeric_columns", sum(!vapply(d[, ..numeric_fields], is.numeric, logical(1))))
  test("schema", "eligibility_logical", as.integer(!is.logical(d$ratio_eligible)))
  gate()
  fips50 <- c(1,2,4,5,6,8,9,10,12,13,15,16,17,18,19,20,21,22,23,24,25,
              26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,
              46,47,48,49,50,51,53,54,55,56)
  state_map <- data.table(STATEFIP = c(fips50, 11),
                          state_name = c(state.name, "District of Columbia"),
                          state_abbr = c(state.abb, "DC"))
  bad_equal <- function(x, y) {
    sum(!(is.na(x) & is.na(y)) & (is.na(x) | is.na(y) | x != y), na.rm = TRUE)
  }
  constraints <- list(
    YEAR = is.finite(d$YEAR) & d$YEAR == 2024,
    SAMPLE = is.finite(d$SAMPLE) & d$SAMPLE == 202401,
    SERIAL = is.finite(d$SERIAL),
    NUMPREC = is.finite(d$NUMPREC) & d$NUMPREC == 1,
    PERNUM = is.finite(d$PERNUM) & d$PERNUM == 1,
    GQ = d$GQ %in% c(1,2),
    AGE = is.finite(d$AGE) & d$AGE >= 18 & d$AGE != 999,
    OWNERSHPD = is.finite(d$OWNERSHPD) & d$OWNERSHPD == 22,
    STATEFIP = d$STATEFIP %in% c(fips50, 11),
    RENTGRS = is.finite(d$RENTGRS) & d$RENTGRS > 0,
    HHWT = is.finite(d$HHWT) & d$HHWT > 0)
  for (v in names(constraints)) {
    test("sample", "filter_rule", sum(is.na(constraints[[v]]) | !constraints[[v]]),
         nrow(d), variable = v)
  }
  test("sample", "duplicate_household_keys", sum(duplicated(d, by = c("SAMPLE", "SERIAL"))), nrow(d))
  test("sample", "missing_main_states", length(setdiff(fips50, d$STATEFIP)))
  test("derived", "household_id", bad_equal(d$household_id, paste(d$SAMPLE, d$SERIAL, sep = "_")), nrow(d))
  expected_income <- as.numeric(d$INCTOT)
  status <- fcase(!is.finite(d$INCTOT), "missing", d$INCTOT == 9999999, "not_in_universe",
                  d$INCTOT == 9999998, "unknown", d$INCTOT == 1, "one_dollar_or_break_even",
                  d$INCTOT == 0, "zero", d$INCTOT < 0, "negative", default = "positive")
  expected_income[!status %in% c("positive", "zero", "negative")] <- NA_real_
  expected_hh_income <- as.numeric(d$HHINCOME)
  expected_hh_income[!is.finite(d$HHINCOME) | d$HHINCOME == 9999999] <- NA_real_
  derived_checks <- list(
    income_status = status, annual_income = expected_income,
    annual_household_income = expected_hh_income,
    monthly_gross_rent = as.numeric(d$RENTGRS), annualized_gross_rent = 12 * d$RENTGRS,
    ratio_eligible = is.finite(expected_income) & expected_income > 0,
    age_group = fifelse(d$AGE < 65, "18-64", "65+"),
    study_scope = fifelse(d$STATEFIP == 11, "DC_separate", "main_50_states"),
    state_name = state_map$state_name[match(d$STATEFIP, state_map$STATEFIP)],
    state_abbr = state_map$state_abbr[match(d$STATEFIP, state_map$STATEFIP)])
  for (v in names(derived_checks)) test("derived", "field_consistency",
    bad_equal(d[[v]], derived_checks[[v]]), nrow(d), variable = v)
  for (v in reps) {
    test("weights", "nonfinite_replicate_weights", sum(!is.finite(d[[v]])), nrow(d), variable = v)
    add("weights", "negative_replicate_weights", sum(d[[v]] < 0, na.rm = TRUE),
        n_checked = nrow(d), variable = v)
    add("weights", "zero_replicate_weights", sum(d[[v]] == 0, na.rm = TRUE),
        n_checked = nrow(d), variable = v)
  }
  test("weights", "invalid_person_weights", sum(!is.finite(d$PERWT) | d$PERWT <= 0),
       nrow(d), variable = "PERWT", severity = "warning")
  comparable <- is.finite(d$annual_income) & is.finite(d$annual_household_income)
  test("income", "personal_household_income_difference",
       sum(d$annual_income[comparable] != d$annual_household_income[comparable]),
       sum(comparable), severity = "warning")
  gate()

  # Re-read only lightweight raw columns, once, for independent structural checks.
  xml <- list.files(raw_dir, pattern = "^usa_[0-9]+\\.xml$", full.names = TRUE)
  xml <- xml[file.exists(sub("\\.xml$", ".dat.gz", xml))]
  test("source", "unique_raw_pair", as.integer(length(xml) != 1L))
  gate()
  data_path <- sub("\\.xml$", ".dat.gz", xml)
  source_files <- c(xml, data_path)
  current_md5 <- unname(tools::md5sum(source_files))
  lineage <- metadata$source_files
  test("source", "lineage_schema", as.integer(!is.data.frame(lineage) ||
       !all(c("file", "md5") %in% names(lineage))))
  gate()
  for (i in seq_along(source_files)) {
    saved <- lineage$md5[match(basename(source_files[i]), lineage$file)]
    ok <- length(saved) == 1L && !is.na(saved) && identical(saved, current_md5[i])
    add("source", "raw_md5_matches_cleaning", current_md5[i], saved,
        n_checked = 1, n_failures = as.integer(!ok), variable = basename(source_files[i]),
        status = if (ok) "PASS" else "FAIL", severity = "error")
  }
  ddi <- ipumsr::read_ipums_ddi(xml)
  vi <- ipumsr::ipums_var_info(ddi)
  raw_vars <- c(raw_core, "REPWT1")
  test("source", "missing_raw_columns", length(setdiff(c(raw_vars, reps), vi$var_name)))
  test("schema", "missing_quality_flags", length(setdiff(grep("^Q", vi$var_name, value = TRUE), names(d))))
  gate()
  members <- list(); singles <- list(); raw_counts <- list()
  population_chunks <- list(); other_person_keys <- list()
  n_read <- 0; wrong_sample <- 0; first <- NULL
  member_vars <- c("SAMPLE", "SERIAL", "PERNUM", "NUMPREC", "STATEFIP", "GQ", "HHWT", "OWNERSHPD")
  callback <- function(x, pos) {
    x <- as.data.table(x)
    n_read <<- n_read + nrow(x)
    wrong_sample <<- wrong_sample + sum(!is.finite(x$YEAR) | x$YEAR != 2024 |
                                         !is.finite(x$SAMPLE) | x$SAMPLE != 202401)
    if (is.null(first)) first <<- as.list(x[1, .(HHWT, PERWT, ADJUST, REPWT1)])
    k <- length(members) + 1L
    raw_counts[[k]] <<- x[, .(n = .N), by = .(YEAR, SAMPLE, STATEFIP, GQ)]
    population <- x[STATEFIP %in% c(fips50, 11)]
    population[, living_alone := GQ %in% c(1,2) & is.finite(NUMPREC) & NUMPREC == 1 &
                 is.finite(PERNUM) & PERNUM == 1]
    population_chunks[[k]] <<- population[, {
      valid_weight <- is.finite(PERWT) & PERWT >= 0
      .(n_persons = .N, n_alone = sum(living_alone),
        weighted_population = sum(PERWT[valid_weight]),
        weighted_alone = sum(PERWT[valid_weight & living_alone]),
        n_invalid_person_weights = sum(!valid_weight),
        n_zero_person_weights = sum(PERWT == 0, na.rm = TRUE),
        n_invalid_person_ids = sum(!is.finite(SAMPLE) | !is.finite(SERIAL) |
                                    !is.finite(PERNUM) | PERNUM < 1))
    }, by = STATEFIP]
    other_person_keys[[k]] <<- x[!GQ %in% c(1,2), .(SAMPLE, SERIAL, PERNUM)]
    ordinary <- x[GQ %in% c(1,2)]
    members[[k]] <<- ordinary[, ..member_vars]
    singles[[k]] <<- ordinary[NUMPREC == 1]
    if (n_read %% 500000 == 0) message("Validating raw records: ", format(n_read, big.mark = ","))
    invisible(NULL)
  }
  ipumsr::read_ipums_micro_chunked(ddi, callback = callback, chunk_size = 100000,
    vars = tidyselect::all_of(raw_vars), data_file = data_path, var_attrs = NULL, verbose = FALSE)
  test("raw", "wrong_year_or_sample", wrong_sample, n_read)
  test("raw", "raw_record_count_matches_cleaning", as.integer(n_read != metadata$raw_person_records), n_read)
  rc <- rbindlist(raw_counts)[, .(n = sum(n)), by = .(YEAR, SAMPLE, STATEFIP, GQ)]
  add("raw_counts", paste0("YEAR=", rc$YEAR, ";SAMPLE=", rc$SAMPLE, ";GQ=", rc$GQ),
      rc$n, n_checked = n_read, state_fips = sprintf("%02d", rc$STATEFIP))
  m <- rbindlist(members); s <- rbindlist(singles)
  population_fields <- c("n_persons", "n_alone", "weighted_population", "weighted_alone",
                         "n_invalid_person_weights", "n_zero_person_weights", "n_invalid_person_ids")
  population_stats <- rbindlist(population_chunks)[, lapply(.SD, sum),
                                                  by = STATEFIP, .SDcols = population_fields]
  all_keys <- rbindlist(list(m[, .(SAMPLE, SERIAL, PERNUM)], rbindlist(other_person_keys)))
  test("population", "duplicate_raw_person_keys", sum(duplicated(all_keys,
       by = c("SAMPLE", "SERIAL", "PERNUM"))), nrow(all_keys))
  test("population", "missing_main_states", length(setdiff(fips50, population_stats$STATEFIP)))
  test("population", "invalid_person_identifiers", sum(population_stats$n_invalid_person_ids),
       sum(population_stats$n_persons))
  test("population", "invalid_person_weights", sum(population_stats$n_invalid_person_weights),
       sum(population_stats$n_persons), variable = "PERWT")
  test("population", "nonpositive_state_population_totals",
       sum(!is.finite(population_stats$weighted_population) | population_stats$weighted_population <= 0),
       nrow(population_stats), variable = "PERWT")
  add("population", "raw_person_records", population_stats$n_persons,
      n_checked = population_stats$n_persons, weighted_n = population_stats$weighted_population,
      state_fips = sprintf("%02d", population_stats$STATEFIP), age_scope = "all_ages", variable = "PERWT")
  add("population", "living_alone_person_records", population_stats$n_alone,
      n_checked = population_stats$n_persons, weighted_n = population_stats$weighted_alone,
      state_fips = sprintf("%02d", population_stats$STATEFIP), age_scope = "all_ages", variable = "PERWT")
  add("population", "zero_person_weights", population_stats$n_zero_person_weights,
      n_checked = population_stats$n_persons, state_fips = sprintf("%02d", population_stats$STATEFIP),
      age_scope = "all_ages", variable = "PERWT")
  rm(members, singles, raw_counts, callback, population_chunks, other_person_keys, all_keys)
  test("households", "nonempty_ordinary_members", as.integer(nrow(m) == 0))
  test("households", "missing_member_identifiers", sum(!is.finite(m$SAMPLE) |
    !is.finite(m$SERIAL) | !is.finite(m$PERNUM)), nrow(m))
  test("households", "duplicate_person_keys", sum(duplicated(m, by = c("SAMPLE", "SERIAL", "PERNUM"))), nrow(m))
  gate()
  message("Checking complete household membership across chunk boundaries...")
  hh <- m[, .(
    n_members = .N, declared_size = NUMPREC[1],
    size_agrees = !anyNA(NUMPREC) && uniqueN(NUMPREC) == 1L,
    n_head = sum(PERNUM == 1),
    sequence_ok = identical(sort(as.integer(PERNUM)), seq_len(.N)),
    fields_agree = all(vapply(.SD, function(z) !anyNA(z) && uniqueN(z) == 1L, logical(1))),
    HHWT = HHWT[1]
  ), by = .(SAMPLE, SERIAL), .SDcols = c("STATEFIP", "GQ", "HHWT", "OWNERSHPD")]
  test("households", "inconsistent_NUMPREC", sum(!hh$size_agrees), nrow(hh))
  test("households", "actual_size_differs_from_NUMPREC",
       sum(is.na(hh$declared_size) | hh$n_members != hh$declared_size), nrow(hh))
  test("households", "not_exactly_one_PERNUM_1", sum(hh$n_head != 1L), nrow(hh))
  test("households", "nonconsecutive_person_numbers", sum(!hh$sequence_ok), nrow(hh))
  test("households", "inconsistent_household_fields", sum(!hh$fields_agree), nrow(hh))
  rm(m)

  # Verify implied decimals independently against the first fixed-width record.
  connection <- gzfile(data_path, open = "rt")
  line <- tryCatch(readLines(connection, n = 1L, warn = FALSE), finally = close(connection))
  for (v in names(first)) {
    i <- match(v, vi$var_name)
    digits <- as.numeric(substr(line, vi$start[i], vi$end[i]))
    expected <- digits / 10^vi$imp_decim[i]
    ok <- isTRUE(all.equal(as.numeric(first[[v]]), expected, tolerance = 1e-9))
    add("ddi_scale", "implied_decimal_parsing", first[[v]], expected,
        1, as.integer(!ok), variable = v,
        status = if (ok) "PASS" else "FAIL", severity = "error")
  }
  flow <- function(label, x, unit = "household") add("sample_flow", label, nrow(x),
    n_checked = nrow(x), weighted_n = sum(x$HHWT[is.finite(x$HHWT) & x$HHWT > 0]), variable = unit)
  add("sample_flow", "raw_person_records", n_read, n_checked = n_read, variable = "person_record")
  flow("ordinary_households", hh)
  rm(hh)
  flow("single_person_households", s)
  test("population", "living_alone_raw_count_matches_validated_singles",
       abs(sum(population_stats$n_alone) - nrow(s[STATEFIP %in% c(fips50, 11)])))
  s <- s[is.finite(AGE) & AGE >= 18 & AGE != 999]
  flow("adult_single_person_households", s)
  s <- s[STATEFIP %in% c(fips50, 11)]
  flow("50_states_and_DC", s)
  s <- s[OWNERSHPD == 22]
  flow("cash_renters", s)
  s <- s[is.finite(RENTGRS) & RENTGRS > 0]
  flow("positive_gross_rent", s)
  s <- s[is.finite(HHWT) & HHWT > 0 & PERNUM == 1]
  flow("positive_HHWT", s)
  flow("main_50_states", s[STATEFIP %in% fips50])
  flow("DC_separate", s[STATEFIP == 11])
  test("filtering", "expected_processed_row_count", abs(nrow(s) - nrow(d)), nrow(d))
  gate()
  setorder(s, SAMPLE, SERIAL, PERNUM)
  setorder(d, SAMPLE, SERIAL, PERNUM)
  for (v in raw_vars) test("filtering", "raw_processed_values_match",
    bad_equal(s[[v]], d[[v]]), nrow(d), variable = v)
  rm(s)
  invisible(gc())
  gate()

  # Consolidated state-level distributions and quality-code frequencies.
  state_counts <- d[, .(n = .N, weighted_n = sum(HHWT), n_positive = sum(ratio_eligible),
                        weighted_positive = sum(HHWT[ratio_eligible])), by = STATEFIP]
  add("state_counts", "cleaned_households", state_counts$n, n_checked = state_counts$n,
      weighted_n = state_counts$weighted_n, state_fips = sprintf("%02d", state_counts$STATEFIP))
  add("state_counts", "positive_income_households", state_counts$n_positive,
      n_checked = state_counts$n, weighted_n = state_counts$weighted_positive,
      state_fips = sprintf("%02d", state_counts$STATEFIP))
  statuses <- d[, .(n = .N, weighted_n = sum(HHWT)), by = .(STATEFIP, income_status)]
  add("income_codes", statuses$income_status, statuses$n, weighted_n = statuses$weighted_n,
      state_fips = sprintf("%02d", statuses$STATEFIP), variable = "INCTOT")
  for (v in grep("^Q", names(d), value = TRUE)) {
    codes <- d[, .(n = .N, weighted_n = sum(HHWT)), by = .(STATEFIP, code = get(v))]
    add("quality_codes", paste0("code=", codes$code), codes$n, weighted_n = codes$weighted_n,
        state_fips = sprintf("%02d", codes$STATEFIP), variable = v)
  }
  d[, rent_income_ratio := NA_real_]
  d[ratio_eligible == TRUE, rent_income_ratio := annualized_gross_rent / annual_income]
  test("ratios", "nonfinite_eligible_ratios", sum(!is.finite(d$rent_income_ratio[d$ratio_eligible])),
       sum(d$ratio_eligible))
  add("ratios", "ratio_above_one", sum(d$rent_income_ratio > 1, na.rm = TRUE),
      n_checked = sum(d$ratio_eligible))
  for (v in c(numeric_fields, "rent_income_ratio")) {
    values <- d[[v]]
    finite <- values[is.finite(values)]
    add("variable_profile", c("n_missing", "n_nonfinite", "minimum", "maximum"),
        c(sum(is.na(values)), sum(!is.finite(values)),
          if (length(finite)) min(finite) else NA_real_,
          if (length(finite)) max(finite) else NA_real_), n_checked = nrow(d), variable = v)
  }
  gate()

  # Descriptive distributions retain weighted empirical-CDF quantiles and SD.
  # Only burden proportions need replicate SEs for the final three figures.
  # Medians and other distribution summaries are reported as point estimates.
  # Signed replicate weights are retained for proportions. No arbitrary capping.
  # SDR SE: sqrt((4/80) * sum((replicate - HHWT estimate)^2)); normal 95% CI.
  # https://usa.ipums.org/usa/repwt.shtml
  core_metrics <- c("median_annual_income_all_valid", "median_annualized_gross_rent_all",
                    "median_rent_income_ratio_positive", "burden_share_over30_positive",
                    "burden_share_over50_positive")
  prepare_series <- function(x) {
    idx <- which(is.finite(x))
    idx <- idx[order(x[idx])]
    list(x = x[idx], idx = idx)
  }
  quantiles <- function(series, w, probs = c(.25, .5, .75)) {
    weights <- w[series$idx]
    total <- sum(weights)
    if (!length(weights) || any(!is.finite(weights)) || any(weights < 0) || total <= 0) {
      return(rep(NA_real_, length(probs)))
    }
    cumulative <- cumsum(weights)
    vapply(probs, function(p) series$x[which(cumulative >= p * total)[1L]], numeric(1))
  }
  share <- function(condition, w) {
    total <- sum(w)
    if (!length(w) || !is.finite(total) || total <= 0) return(NA_real_)
    sum(w[condition]) / total
  }
  estimate_domain <- function(x, geography, fips, name, abbr, age_scope) {
    series <- list(income = prepare_series(x$annual_income),
                   rent = prepare_series(x$annualized_gross_rent),
                   ratio = prepare_series(x$rent_income_ratio))
    pos <- which(x$ratio_eligible)
    r <- x$rent_income_ratio[pos]
    calculate_core <- function(w) c(
      quantiles(series$income, w, .5), quantiles(series$rent, w, .5),
      quantiles(series$ratio, w, .5), share(r > .30, w[pos]), share(r > .50, w[pos]))
    point <- calculate_core(x$HHWT)
    # Recompute only >30% and >50% shares across the 80 replicates.
    # No repeated sorting or replicate-quantile calculations are needed.
    replica <- vapply(reps, function(v) c(
      share(r > .30, x[[v]][pos]), share(r > .50, x[[v]][pos])), numeric(2))
    se <- rep(NA_real_, length(core_metrics))
    se[4:5] <- vapply(seq_len(2), function(j) {
      if (!is.finite(point[j + 3L]) || any(!is.finite(replica[j, ]))) return(NA_real_)
      sqrt((4/80) * sum((replica[j, ] - point[j + 3L])^2))
    }, numeric(1))
    ci_status <- rep("not_requested", length(core_metrics))
    ci_status[!is.finite(point)] <- "point_estimate_unavailable"
    ci_status[4:5] <- ifelse(!is.finite(point[4:5]), "point_estimate_unavailable",
                            ifelse(!is.finite(se[4:5]), "replicate_estimate_unavailable", "ok"))
    result <- data.table(metric = core_metrics, estimate = point, standard_error = se,
                         ci95_lower = point - stats::qnorm(.975) * se,
                         ci95_upper = point + stats::qnorm(.975) * se, ci_status = ci_status,
                         unit = c("USD_per_year", "USD_per_year", "ratio", "proportion", "proportion"),
                         denominator = c("defined_income", "all_cleaned", rep("positive_income", 3)))
    extras <- lapply(seq_along(series), function(i) {
      v <- series[[i]]; w <- x$HHWT[v$idx]
      total <- sum(w)
      q <- quantiles(v, x$HHWT, c(.25, .75))
      mu <- if (total > 0) sum(v$x * w) / total else NA_real_
      sd <- if (total > 0) sqrt(sum(w * (v$x - mu)^2) / total) else NA_real_
      suffix <- c("annual_income_all_valid", "annualized_gross_rent_all", "rent_income_ratio_positive")[i]
      data.table(metric = paste0(c("p25_", "p75_", "mean_", "sd_"), suffix),
                  estimate = c(q, mu, sd), standard_error = NA_real_,
                  ci95_lower = NA_real_, ci95_upper = NA_real_, ci_status = "not_requested",
                  unit = c("USD_per_year", "USD_per_year", "ratio")[i],
                  denominator = c("defined_income", "all_cleaned", "positive_income")[i])
    })
    result <- rbindlist(c(list(result), extras))
    valid <- is.finite(x$annual_income)
    result[, `:=`(geography = geography, STATEFIP = as.integer(fips), state_name = name,
                   state_abbr = abbr, age_scope = age_scope,
                   n_domain_households = nrow(x), weighted_domain_households = sum(x$HHWT),
                   n_positive_income_households = length(pos),
                   weighted_positive_income_households = sum(x$HHWT[pos]),
                   n_zero_income_households = sum(x$income_status == "zero"),
                   n_negative_income_households = sum(x$income_status == "negative"),
                   n_ambiguous_income_households = sum(x$income_status == "one_dollar_or_break_even"),
                   weighted_age65plus_share = sum(x$HHWT[x$AGE >= 65]) / sum(x$HHWT))]
    result[, n_denominator := fcase(denominator == "defined_income", sum(valid),
                                    denominator == "all_cleaned", nrow(x), default = length(pos))]
    result[, weighted_denominator := fcase(denominator == "defined_income", sum(x$HHWT[valid]),
      denominator == "all_cleaned", sum(x$HHWT), default = sum(x$HHWT[pos]))]
    result[, `:=`(run_id = run_id, processed_md5 = process_md5,
                   observation_unit = "household", weight_variable = "HHWT")]
    result
  }
  results <- list()
  add_domain <- function(x, geo, fips, name, abbr) {
    if (!nrow(x)) return(invisible(NULL))
    for (a in c("all_adults", "18-64", "65+")) {
      sub <- if (a == "all_adults") x else x[age_group == a]
      if (nrow(sub)) results[[length(results) + 1L]] <<- estimate_domain(sub, geo, fips, name, abbr, a)
    }
    invisible(NULL)
  }
  main <- d[study_scope == "main_50_states"]
  for (code in fips50) {
    x <- main[STATEFIP == code]
    message("Estimating ", x$state_name[1], "...")
    add_domain(x, "state", code, x$state_name[1], x$state_abbr[1])
  }
  add_domain(main, "pooled_50_states", NA_integer_, "50 states pooled (excluding DC)", "US50")
  add_domain(d[study_scope == "DC_separate"], "DC_separate", 11, "District of Columbia", "DC")
  # Append population context to the SAME statistical CSV. Person replicate
  # weights are not requested by the current extract; no population CI is made
  # from household replicate weights. These two metrics are point estimates.
  population_rows <- function(p, geo, fips, name, abbr) data.table(
    run_id = run_id, processed_md5 = process_md5,
    geography = geo, STATEFIP = as.integer(fips), state_name = name, state_abbr = abbr,
    age_scope = "all_ages", observation_unit = "person",
    metric = c("living_alone_population_share", "living_alone_sample_record_share"),
    unit = c("proportion", "sample_proportion"),
    denominator = c("resident_population_including_group_quarters", "raw_person_records"),
    weight_variable = c("PERWT", "none"),
    estimate = c(p$weighted_alone / p$weighted_population, p$n_alone / p$n_persons),
    standard_error = NA_real_, ci95_lower = NA_real_, ci95_upper = NA_real_, ci_status = "not_requested",
    n_denominator = as.numeric(p$n_persons), weighted_denominator = p$weighted_population,
    n_numerator = as.numeric(p$n_alone), weighted_numerator = p$weighted_alone)
  population_results <- lapply(seq_len(nrow(population_stats)), function(i) {
    p <- population_stats[i]
    j <- match(p$STATEFIP, state_map$STATEFIP)
    population_rows(p, if (p$STATEFIP == 11) "DC_separate" else "state", p$STATEFIP,
                    state_map$state_name[j], state_map$state_abbr[j])
  })
  pooled_population <- population_stats[STATEFIP %in% fips50, lapply(.SD, sum),
                                        .SDcols = population_fields]
  population_results[[length(population_results) + 1L]] <- population_rows(
    pooled_population, "pooled_50_states", NA_integer_, "50 states pooled (excluding DC)", "US50")
  population_summary <- rbindlist(population_results)
  test("population", "invalid_population_or_sample_shares", sum(!is.finite(population_summary$estimate) |
       population_summary$estimate < 0 | population_summary$estimate > 1), nrow(population_summary))
  state_population <- population_summary[geography == "state" & metric == "living_alone_population_share"]
  pooled_share <- population_summary[geography == "pooled_50_states" & metric == "living_alone_population_share", estimate]
  reconstructed <- sum(state_population$estimate * state_population$weighted_denominator) /
                     sum(state_population$weighted_denominator)
  test("population", "state_pooled_population_share_consistency",
       as.integer(!isTRUE(all.equal(reconstructed, pooled_share, tolerance = 1e-10))))
  summary <- rbindlist(c(results, list(population_summary)), use.names = TRUE, fill = TRUE)
  for (j in seq_len(nrow(summary))) {
    z <- summary[j]
    if (z$ci_status %in% c("ok", "not_requested")) next
    add("uncertainty", z$ci_status, z$estimate, n_checked = z$n_denominator,
        status = "WARN", severity = "warning", geography = z$geography,
        state_fips = if (is.na(z$STATEFIP)) NA_character_ else sprintf("%02d", z$STATEFIP),
        age_scope = z$age_scope, variable = z$metric)
  }
  p30 <- summary[metric == "burden_share_over30_positive" & n_denominator > 0]
  p50 <- summary[metric == "burden_share_over50_positive" & n_denominator > 0]
  test("statistics", "nested_burden_shares", sum(!is.finite(p30$estimate) |
    !is.finite(p50$estimate) | p50$estimate < 0 | p50$estimate > p30$estimate | p30$estimate > 1), nrow(p30))
  for (metric_name in core_metrics) {
    z <- summary[geography == "state" & age_scope == "all_adults" & metric == metric_name]
    test("statistics", "missing_state_point_estimates", sum(!is.finite(z$estimate)) + abs(nrow(z) - 50),
         50, variable = metric_name)
  }
  for (metric_name in tail(core_metrics, 2)) {
    z <- summary[geography == "state" & age_scope == "all_adults" & metric == metric_name]
    pooled <- summary[geography == "pooled_50_states" & age_scope == "all_adults" & metric == metric_name, estimate]
    reconstructed <- sum(z$estimate * z$weighted_denominator) / sum(z$weighted_denominator)
    test("statistics", "state_pooled_share_consistency",
         as.integer(!isTRUE(all.equal(reconstructed, pooled, tolerance = 1e-10))), variable = metric_name)
  }
  test("statistics", "duplicate_summary_keys", sum(duplicated(summary,
    by = c("geography", "STATEFIP", "age_scope", "metric"))), nrow(summary))
  gate()
  setcolorder(summary, c("run_id", "processed_md5", "geography", "STATEFIP", "state_name", "state_abbr",
    "age_scope", "metric", "unit", "denominator", "estimate", "standard_error", "ci95_lower",
    "ci95_upper", "ci_status", "n_denominator", "weighted_denominator"))
  setorder(summary, geography, STATEFIP, age_scope, metric)
  fwrite(summary, summary_path, na = "NA")
  add("pipeline", "analysis_completed", observed = 1, expected = 1,
      n_checked = 1, n_failures = 0, status = "PASS", severity = "error")
  write_report()
  message("Complete: data_validation_report.csv + statistical_summary.csv")
  message("No separate diagnostics or interpretation files were written. Next: 04_make_figures.R.")
  invisible(c(validation_path, summary_path))
}

run_blog5_analysis()
