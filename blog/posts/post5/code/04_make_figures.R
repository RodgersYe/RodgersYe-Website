# Blog 5 | 04: three final PNG figures from the single statistical summary.
# Console: source(here::here("blog", "posts", "post5", "code", "04_make_figures.R"))
# Outputs: fig01 intervals, fig02 severe-burden map, fig03 living-alone map; 300 dpi.
# After all three exports succeed, remove the five obsolete filenames from the
# previous layout. Other files in figures/ are left untouched.
# No CSV, TXT, PDF, figure manifest, or diagnostic directory is created.
# The official Census boundary ZIP is cached as raw geography; shapefile
# components are read inside the ZIP, not extracted into more project files.

needed <- c("here", "data.table", "sf", "ggplot2", "scales", "patchwork", "ggrepel")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install: ", paste(missing, collapse = ", "), call. = FALSE)
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(ggplot2))
here::i_am("blog/posts/post5/code/04_make_figures.R")

run_blog5_figures <- function() {
  post_dir <- here::here("blog", "posts", "post5")
  processed <- file.path(post_dir, "data", "processed")
  fig_dir <- file.path(post_dir, "figures")
  geo_dir <- file.path(post_dir, "data", "raw", "geography")
  for (p in c(fig_dir, geo_dir)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
  summary_path <- file.path(processed, "statistical_summary.csv")
  validation_path <- file.path(processed, "data_validation_report.csv")
  if (!all(file.exists(c(summary_path, validation_path)))) {
    stop("Run the NEW 02 and 03 scripts first; both consolidated CSVs are required.", call. = FALSE)
  }
  estimates <- fread(summary_path)
  validation <- fread(validation_path)
  needed_summary <- c("run_id", "processed_md5", "geography", "STATEFIP", "state_name", "state_abbr",
                      "age_scope", "metric", "estimate", "ci95_lower", "ci95_upper", "ci_status")
  needed_checks <- c("run_id", "section", "check", "observed", "status")
  if (!all(needed_summary %in% names(estimates)) || !all(needed_checks %in% names(validation))) {
    stop("CSV schema is incompatible. Rerun the new 03 script.", call. = FALSE)
  }
  completed <- validation[section == "pipeline" & check == "analysis_completed" & status == "PASS"]
  lineage <- validation[section == "input" & check == "processed_md5", observed]
  if (anyNA(validation$status) || any(validation$status == "FAIL") || nrow(completed) != 1L ||
      uniqueN(estimates$run_id) != 1L || uniqueN(estimates$processed_md5) != 1L ||
      anyNA(estimates$run_id) || anyNA(estimates$processed_md5) ||
      !identical(unique(estimates$run_id), completed$run_id) ||
      !identical(unique(estimates$processed_md5), lineage)) {
    stop("Reports do not belong to one completed, valid analysis run. Rerun 03.", call. = FALSE)
  }
  clean_path <- file.path(processed, "single_person_renters_clean.rds")
  if (file.exists(clean_path) && !identical(unname(tools::md5sum(clean_path)), lineage)) {
    stop("The processed dataset changed after these reports were written. Rerun 03.", call. = FALSE)
  }
  # The retained figures need one burden metric, rather than all five
  # original metrics or a wide table of income/rent/median-ratio estimates.
  burden <- estimates[geography == "state" & age_scope == "all_adults" &
                        metric == "burden_share_over50_positive"]
  d <- burden[, .(STATEFIP, state_name, state_abbr, severe_share = estimate,
                    ci_low = ci95_lower, ci_high = ci95_upper, ci_status)]
  fips50 <- c(1,2,4,5,6,8,9,10,12,13,15,16,17,18,19,20,21,22,23,24,25,
              26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,
              46,47,48,49,50,51,53,54,55,56)
  if (nrow(d) != 50L || anyDuplicated(d$STATEFIP) || !setequal(d$STATEFIP, fips50)) {
    stop("Expected one row for each of the 50 states.", call. = FALSE)
  }
  d[, state_fips := sprintf("%02d", STATEFIP)]
  if (any(!is.finite(d$severe_share) | d$severe_share < 0 | d$severe_share > 1)) {
    stop("A severe-burden point estimate is invalid.", call. = FALSE)
  }
  # Missing intervals stay missing; all available point estimates are shown.
  d[is.na(ci_status) | ci_status != "ok", `:=`(ci_low = NA_real_, ci_high = NA_real_)]
  usable_ci <- !is.na(d$ci_status) & d$ci_status == "ok"
  if (any(usable_ci & (!is.finite(d$ci_low) | !is.finite(d$ci_high) |
                        d$ci_low > d$severe_share | d$ci_high < d$severe_share))) {
    stop("An interval marked available has invalid bounds.", call. = FALSE)
  }
  national_severe <- estimates[geography == "pooled_50_states" & age_scope == "all_adults" &
                                metric == "burden_share_over50_positive"]
  if (nrow(national_severe) != 1L || !is.finite(national_severe$estimate)) {
    stop("Missing pooled national severe-burden estimate.", call. = FALSE)
  }
  population <- estimates[geography == "state" & age_scope == "all_ages" &
                            metric == "living_alone_population_share"]
  if (nrow(population) != 50L || anyDuplicated(population$STATEFIP) ||
      !setequal(population$STATEFIP, fips50) ||
      any(!is.finite(population$estimate) | population$estimate < 0 | population$estimate > 1)) {
    stop("Missing or invalid living-alone population estimates. Run the updated 03 script.", call. = FALSE)
  }
  d[, living_alone_share := population$estimate[match(STATEFIP, population$STATEFIP)]]

  geo_name <- "cb_2024_us_state_20m"
  geo_url <- paste0("https://www2.census.gov/geo/tiger/GENZ2024/shp/", geo_name, ".zip")
  zip_path <- file.path(geo_dir, paste0(geo_name, ".zip"))
  if (!file.exists(zip_path)) {
    message("Downloading official 2024 Census state boundaries...")
    old_timeout <- getOption("timeout")
    options(timeout = max(300, old_timeout))
    on.exit(options(timeout = old_timeout), add = TRUE)
    temporary <- tempfile(tmpdir = geo_dir, fileext = ".zip")
    on.exit(unlink(temporary), add = TRUE)
    status <- utils::download.file(geo_url, temporary, mode = "wb")
    if (status != 0 || !file.exists(temporary) || file.info(temporary)$size <= 0 ||
        !file.rename(temporary, zip_path)) stop("Census boundary download failed.", call. = FALSE)
  }
  entries <- utils::unzip(zip_path, list = TRUE)$Name
  required_geo <- paste0(geo_name, c(".shp", ".shx", ".dbf", ".prj"))
  if (!all(required_geo %in% entries)) stop("Census ZIP lacks required shapefile components.", call. = FALSE)
  vsi_path <- paste0("/vsizip/", normalizePath(zip_path, winslash = "/", mustWork = TRUE),
                     "/", geo_name, ".shp")
  states <- sf::st_read(vsi_path, quiet = TRUE)
  if (!all(c("STATEFP", "STUSPS", "NAME") %in% names(states))) {
    stop("Unexpected boundary attributes.", call. = FALSE)
  }
  states$state_fips <- sprintf("%02d", as.integer(states$STATEFP))
  states <- states[states$state_fips %in% d$state_fips, ]
  if (nrow(states) != 50L || anyDuplicated(states$state_fips)) {
    stop("Boundary file does not uniquely cover all 50 states.", call. = FALSE)
  }
  geometry_ok <- sf::st_is_valid(states)
  if (anyNA(geometry_ok) || any(!geometry_ok)) states <- sf::st_make_valid(states)
  match_index <- match(states$state_fips, d$state_fips)
  if (anyNA(match_index) || anyNA(states$STUSPS) || any(states$STUSPS != d$state_abbr[match_index])) {
    stop("FIPS/abbreviation join failed.", call. = FALSE)
  }
  for (v in c("state_abbr", "state_name", "severe_share", "living_alone_share")) {
    states[[v]] <- d[[v]][match_index]
  }

  # English labels match the website's existing blog style; common sans font.
  orange <- c("#FFF5EB", "#FEE6CE", "#FDAE6B", "#E6550D", "#A63603")
  severe_limits <- c(floor(min(d$severe_share) / .05) * .05,
                     ceiling(max(d$severe_share) / .05) * .05)
  pct <- scales::label_percent(accuracy = 1)
  source_caption <- "Source: IPUMS USA, 2024 ACS 1-year. HHWT-weighted; 50 states; DC excluded."
  sample_caption <- "Adults living alone, paying cash rent, with defined positive income. Gross rent includes utilities/fuel."
  map_theme <- theme_void(base_size = 11, base_family = "sans") + theme(
    plot.background = element_rect(fill = "white", colour = NA),
    plot.title = element_text(face = "bold", colour = "#202020", size = 11),
    legend.title = element_text(size = 10), legend.text = element_text(size = 9),
    plot.margin = margin(4, 6, 4, 6))
  chart_theme <- theme_minimal(base_size = 11, base_family = "sans") + theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 10.5, colour = "#4D4D4D"),
    plot.caption = element_text(size = 9, colour = "#555555", hjust = 0),
    panel.grid.minor = element_blank(), plot.background = element_rect(fill = "white", colour = NA),
    plot.margin = margin(12, 14, 12, 12))
  annotation_theme <- theme(
    plot.title = element_text(face = "bold", size = 17, colour = "#202020"),
    plot.subtitle = element_text(size = 11, colour = "#4D4D4D"),
    plot.caption = element_text(size = 9, colour = "#555555", hjust = 0),
    plot.background = element_rect(fill = "white", colour = NA),
    plot.margin = margin(10, 12, 10, 12))
  
  # Separate Alaska/Hawaii panels preserve all 50 states without treating a
  # display shift as real geography. Hawaii view shows its main populated islands.
  make_map <- function(metric, limits, legend_title, title, subtitle, note,
                        source_text = source_caption,
                        sample_text = sample_caption, break_step = .05) {
    geo48 <- sf::st_transform(states[!states$state_abbr %in% c("AK", "HI"), ], 5070)
    geo48$map_value <- geo48[[metric]]
    anchors <- sf::st_point_on_surface(sf::st_geometry(geo48))
    coordinates <- sf::st_coordinates(anchors)
    labels <- as.data.frame(sf::st_drop_geometry(geo48))
    labels$x <- coordinates[, 1]; labels$y <- coordinates[, 2]
    callouts <- c("CT", "RI", "MA", "NJ", "DE", "MD", "NH", "VT")
    labels$text_colour <- ifelse(labels$map_value > limits[1] + .80 * diff(limits),
                                 "white", "#252525")
    fill_scale <- function() scale_fill_gradientn(
      colours = orange, limits = limits, breaks = seq(limits[1], limits[2], by = break_step),
      labels = pct, name = legend_title,
      guide = guide_colourbar(barwidth = grid::unit(95, "mm"),
                              barheight = grid::unit(3, "mm"), title.position = "top"))
    bbox <- sf::st_bbox(geo48)
    p48 <- ggplot(geo48) + geom_sf(aes(fill = map_value), colour = "white", linewidth = .3) +
      geom_text(data = labels[!labels$state_abbr %in% callouts, ],
                aes(x = x, y = y, label = state_abbr, colour = text_colour),
                size = 2.6, fontface = "bold", show.legend = FALSE) +
      scale_colour_identity() +
      ggrepel::geom_text_repel(data = labels[labels$state_abbr %in% callouts, ],
                               aes(x = x, y = y, label = state_abbr), size = 2.6,
                               nudge_x = 280000, direction = "y", seed = 2024, max.overlaps = Inf,
                               min.segment.length = 0, segment.colour = "#737373", segment.size = .3,
                               colour = "#252525", box.padding = .3) +
      fill_scale() + coord_sf(crs = 5070, datum = NA,
                              xlim = c(bbox["xmin"], bbox["xmax"] + 380000), expand = FALSE, clip = "off") + map_theme
    ak <- sf::st_transform(states[states$state_abbr == "AK", ], 3338)
    hi <- sf::st_transform(states[states$state_abbr == "HI", ], 4326)
    ak$map_value <- ak[[metric]]; hi$map_value <- hi[[metric]]
    pak <- ggplot(ak) + geom_sf(aes(fill = map_value), colour = "white", linewidth = .3) +
      fill_scale() + coord_sf(crs = 3338, datum = NA, expand = FALSE) + map_theme +
      labs(title = paste0("Alaska  ", scales::percent(ak$map_value, accuracy = .1)))
    phi <- ggplot(hi) + geom_sf(aes(fill = map_value), colour = "white", linewidth = .3) +
      fill_scale() + coord_sf(crs = 4326, datum = NA, expand = FALSE,
                              xlim = c(-161, -154), ylim = c(18.7, 22.6)) + map_theme +
      labs(title = paste0("Hawaii  ", scales::percent(hi$map_value, accuracy = .1)))
    patchwork::wrap_plots(list(p48, pak, phi), design = "AA\nBC",
                          heights = c(4, 1.2), guides = "collect") +
      patchwork::plot_annotation(title = title, subtitle = subtitle,
                                 caption = paste(source_text, sample_text,
                                                 "Boundaries: Census Bureau 2024. Alaska/Hawaii panels use different scales; Hawaii shows main islands.",
                                                 note, sep = "\n"), theme = annotation_theme) &
      theme(legend.position = "bottom")
  }
  fig2 <- make_map(
    "severe_share", severe_limits, "Households spending more than half their income on gross rent",
    "Severe rent burden among people living alone",
    "Share of positive-income single-person renters with annualized gross rent above 50% of income, 2024",
    "Map shows point estimates. See the companion interval chart for uncertainty.")
  
  # Show available severe-burden intervals.
  # Ordering is descriptive, not a test of differences between states.
  interval_data <- copy(d)
  setorder(interval_data, severe_share, state_name)
  interval_data[, state_order := factor(state_name, levels = state_name)]
  fig1 <- ggplot(interval_data, aes(x = severe_share, y = state_order)) +
    geom_vline(xintercept = national_severe$estimate, linetype = "dashed",
               colour = "#666666", linewidth = .45) +
    geom_segment(aes(x = ci_low, xend = ci_high, yend = state_order),
                 colour = "#8C8C8C", linewidth = .55, na.rm = TRUE) +
    geom_point(colour = "#A63603", size = 2.2) +
    scale_x_continuous(labels = scales::label_percent(accuracy = 1),
                       breaks = seq(0, 1, .05), expand = expansion(mult = c(.04, .04))) +
    labs(title = "Severe rent burden across the 50 states",
         subtitle = paste0("Share spending more than half of income on gross rent; dots and available 95% confidence intervals\n",
                           "Dashed line: pooled 50-state estimate, ",
                           scales::percent(national_severe$estimate, accuracy = .1)),
         x = "Share of positive-income single-person renter households", y = NULL,
         caption = paste(source_caption, sample_caption,
                         paste0("Intervals: 80 household replicate weights (ACS SDR); unavailable for ",
                                sum(!is.finite(d$ci_low) | !is.finite(d$ci_high)), " states. Point ordering is descriptive."),
                         sep = "\n")) + chart_theme +
    theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(size = 9))
  
  population_limits <- c(floor(min(d$living_alone_share) / .02) * .02,
                          ceiling(max(d$living_alone_share) / .02) * .02)
  if (diff(population_limits) == 0) population_limits[2] <- population_limits[1] + .02
  fig3 <- make_map(
    "living_alone_share", population_limits, "Residents living alone (% of total population)",
    "Where living alone is more common",
    "People living alone as a share of all state residents, 2024",
    "Descriptive point estimates. Population composition differs from the adult renter sample in the burden maps.",
    source_text = "Source: IPUMS USA, 2024 ACS 1-year. PERWT-weighted; 50 states; DC excluded.",
    sample_text = paste("All ages and housing tenures. Denominator: all residents, including group quarters.",
                        "Living alone: household residents with NUMPREC=1; GQ in {1,2}.", sep = "\n"),
    break_step = .02)
  figures <- list(fig1, fig2, fig3)
  filenames <- c("fig01_severe_burden_intervals", "fig02_severe_rent_burden_map",
                  "fig03_living_alone_population_share_map")
  widths <- c(9, 11, 11)
  heights <- c(13, 8.5, 9)
  output_paths <- character(length(figures))
  for (i in seq_along(figures)) {
    message("Saving ", filenames[i], "...")
    output_paths[i] <- file.path(fig_dir, paste0(filenames[i], ".png"))
    ggsave(output_paths[i], plot = figures[[i]], width = widths[i], height = heights[i],
           units = "in", dpi = 300, bg = "white")
  }
  output_sizes <- file.info(output_paths)$size
  if (anyNA(output_sizes) || any(output_sizes <= 0)) {
    stop("A figure export is missing or empty.", call. = FALSE)
  }
  # The old and new layouts have distinct full filenames. Retire only the
  # known old names after every replacement image has been saved successfully.
  legacy_paths <- file.path(fig_dir, c(
    "fig01_severe_rent_burden_map.png",
    "fig02_severe_burden_intervals.png",
    "fig03_income_rent_scatter.png",
    "fig04_median_ratio_map.png",
    "fig05_living_alone_population_share_map.png"))
  obsolete <- setdiff(legacy_paths, output_paths)
  obsolete <- obsolete[file.exists(obsolete)]
  if (length(obsolete)) {
    status <- unlink(obsolete)
    if (status != 0L || any(file.exists(obsolete))) {
      stop("Three new figures were saved, but obsolete images could not be removed: ",
           paste(basename(obsolete[file.exists(obsolete)]), collapse = ", "), call. = FALSE)
    }
    message("Removed ", length(obsolete), " obsolete figure files.")
  }
  message("Complete: three PNG figures saved in ", fig_dir)
  invisible(output_paths)
}

run_blog5_figures()
