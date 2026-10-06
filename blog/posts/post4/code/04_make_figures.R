# Blog Post 4 — 04_make_figures.R
# Create three figures from the validated 2024 analysis data.
#
# Rank 1 is highest.
# Positive rank_change means the state moves UP after RPP adjustment.

required_packages <- c(
  "here", "ggplot2", "usmap", "usmapdata", "sf"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    quietly = TRUE,
    FUN.VALUE = logical(1)
  )
]

if (length(missing_packages) > 0) {
  stop(
    "Install these packages first: ",
    paste(missing_packages, collapse = ", "),
    "\nRun: install.packages(c(",
    paste(sprintf('"%s"', missing_packages), collapse = ", "),
    "))"
  )
}

post_dir <- here::here("blog", "posts", "post4")

input_path <- file.path(
  post_dir, "data", "processed",
  "state_income_analysis_2024.csv"
)

figures_dir <- file.path(post_dir, "figures")

if (!file.exists(input_path)) {
  stop(
    "Analysis file not found. Run 02_clean_data.R ",
    "and 03_analyze_data.R first."
  )
}

x <- utils::read.csv(
  input_path,
  colClasses = c(GeoFips = "character"),
  stringsAsFactors = FALSE
)

required_columns <- c(
  "GeoFips", "state", "year",
  "nominal_pcpi", "rpp_all_items", "adjusted_pcpi",
  "nominal_rank", "adjusted_rank", "rank_change"
)

if (
  !all(required_columns %in% names(x)) ||
  nrow(x) != 50 ||
  !setequal(x$state, state.name) ||
  anyDuplicated(x$state) > 0 ||
  anyNA(x[required_columns]) ||
  !all(as.character(x$year) == "2024")
) {
  stop("The analysis file failed the 50-state validation.")
}

if (
  !all(x$rank_change == x$nominal_rank - x$adjusted_rank) ||
  !setequal(x$nominal_rank, 1:50) ||
  !setequal(x$adjusted_rank, 1:50)
) {
  stop("The ranking variables failed validation.")
}

# BEA uses five-character state GeoFips, such as "01000".
# usmapdata uses the first two characters, such as "01".
x$fips <- substr(x$GeoFips, 1, 2)
x$abbr <- state.abb[match(x$state, state.name)]

if (
  anyNA(x$abbr) ||
  anyDuplicated(x$fips) > 0 ||
  any(nchar(x$fips) != 2)
) {
  stop("Could not match every state to its map identifier.")
}

dir.create(
  figures_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

make_rank_map <- function(rank_column, title, subtitle) {
  if (!rank_column %in% c("nominal_rank", "adjusted_rank")) {
    stop("Unexpected rank column.")
  }
  
  map_data <- data.frame(
    fips = x$fips,
    income_rank = x[[rank_column]],
    stringsAsFactors = FALSE
  )
  
  labels_data <- usmapdata::centroid_labels(
    "states",
    data_year = 2024
  )
  
  labels_data <- labels_data[
    labels_data$abbr %in% state.abb,
  ]
  
  labels_data$income_rank <- map_data$income_rank[
    match(labels_data$fips, map_data$fips)
  ]
  
  if (
    nrow(labels_data) != 50 ||
    anyNA(labels_data$income_rank)
  ) {
    stop("Could not match map labels to all 50 states.")
  }
  
  # Six small states receive labels in a fixed column
  # to the right of the map.
  crowded_abbr <- c("MA", "RI", "CT", "NJ", "MD", "DE")
  
  crowded_states <- labels_data[
    labels_data$abbr %in% crowded_abbr,
  ]
  
  regular_states <- labels_data[
    !labels_data$abbr %in% crowded_abbr,
  ]
  
  dark_states <- regular_states[
    regular_states$income_rank <= 12,
  ]
  
  light_states <- regular_states[
    regular_states$income_rank > 12,
  ]
  
  anchor_coordinates <- sf::st_coordinates(
    crowded_states
  )
  
  if (nrow(anchor_coordinates) != 6) {
    stop("Expected six northeastern label locations.")
  }
  
  callouts <- data.frame(
    abbr = crowded_states$abbr,
    anchor_x = anchor_coordinates[, "X"],
    anchor_y = anchor_coordinates[, "Y"],
    stringsAsFactors = FALSE
  )
  
  callout_order <- c("MA", "RI", "CT", "NJ", "MD", "DE")
  
  callouts <- callouts[
    match(callout_order, callouts$abbr),
  ]
  
  if (
    nrow(callouts) != 6 ||
    anyNA(callouts)
  ) {
    stop("Could not arrange the northeastern labels.")
  }
  
  map_geometry <- usmapdata::us_map(
    regions = "states",
    include = state.abb,
    data_year = 2024
  )
  
  map_bbox <- sf::st_bbox(map_geometry)
  
  map_width <- as.numeric(
    map_bbox["xmax"] - map_bbox["xmin"]
  )
  
  map_height <- as.numeric(
    map_bbox["ymax"] - map_bbox["ymin"]
  )
  
  # These positions are computed from the map coordinates,
  # so the same arrangement is used for both maps.
  callouts$label_x <- as.numeric(map_bbox["xmax"]) +
    0.025 * map_width
  
  callouts$label_y <- seq(
    from = max(callouts$anchor_y) +
      0.015 * map_height,
    to = min(callouts$anchor_y) -
      0.015 * map_height,
    length.out = nrow(callouts)
  )
  
  if (rank_column == "nominal_rank") {
    source_note <- paste(
      "Source: BEA SAINC1, September 26, 2025 release.",
      "2024 data; D.C. excluded.",
      "Color indicates rank, not the size of income differences."
    )
  } else {
    source_note <- paste(
      "Source: BEA SAINC1, September 26, 2025 release,",
      "and BEA SARPP.",
      "2024 data; D.C. excluded.",
      "Color indicates rank, not the size of income differences."
    )
  }
  
  usmap::plot_usmap(
    regions = "states",
    data = map_data,
    values = "income_rank",
    include = state.abb,
    data_year = 2024,
    labels = FALSE,
    color = "#52606D",
    linewidth = 0.25
  ) +
    ggplot2::geom_sf_text(
      data = light_states,
      mapping = ggplot2::aes(label = abbr),
      inherit.aes = FALSE,
      color = "#263544",
      size = 3.1,
      fontface = "plain"
    ) +
    ggplot2::geom_sf_text(
      data = dark_states,
      mapping = ggplot2::aes(label = abbr),
      inherit.aes = FALSE,
      color = "white",
      size = 3.1,
      fontface = "plain"
    ) +
    ggplot2::geom_segment(
      data = callouts,
      mapping = ggplot2::aes(
        x = anchor_x,
        y = anchor_y,
        xend = label_x,
        yend = label_y
      ),
      inherit.aes = FALSE,
      color = "#52606D",
      linewidth = 0.35
    ) +
    ggplot2::geom_point(
      data = callouts,
      mapping = ggplot2::aes(
        x = anchor_x,
        y = anchor_y
      ),
      inherit.aes = FALSE,
      shape = 21,
      size = 1.5,
      stroke = 0.35,
      fill = "white",
      color = "#52606D"
    ) +
    ggplot2::geom_text(
      data = callouts,
      mapping = ggplot2::aes(
        x = label_x,
        y = label_y,
        label = abbr
      ),
      inherit.aes = FALSE,
      hjust = -0.15,
      color = "#263544",
      size = 3.1,
      fontface = "bold"
    ) +
    ggplot2::scale_fill_gradient(
      name = "Rank among 50 states\n(1 = highest)",
      low = "#8E2634",
      high = "#FFFFFF",
      limits = c(1, 50),
      breaks = c(1, 10, 20, 30, 40, 50),
      guide = ggplot2::guide_colorbar(
        reverse = TRUE
      )
    ) +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      caption = source_note
    ) +
    ggplot2::theme_void(base_size = 13) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold",
        size = 21,
        margin = ggplot2::margin(b = 6)
      ),
      plot.subtitle = ggplot2::element_text(
        size = 12,
        margin = ggplot2::margin(b = 12)
      ),
      plot.caption = ggplot2::element_text(
        size = 9,
        color = "#667789",
        hjust = 0,
        margin = ggplot2::margin(t = 14)
      ),
      legend.position = "right",
      legend.title = ggplot2::element_text(size = 10),
      legend.text = ggplot2::element_text(size = 9),
      plot.margin = ggplot2::margin(18, 22, 18, 22)
    )
}

nominal_map <- make_rank_map(
  rank_column = "nominal_rank",
  title = "Which states rank highest in personal income?",
  subtitle = paste(
    "Nominal per-capita personal income",
    "\u00b7 2024 \u00b7 50 states"
  )
)

adjusted_map <- make_rank_map(
  rank_column = "adjusted_rank",
  title = "Which states rank highest after adjusting for prices?",
  subtitle = paste(
    "RPP-adjusted per-capita personal income",
    "\u00b7 2024 \u00b7 50 states"
  )
)

nominal_path <- file.path(
  figures_dir,
  "01_nominal_pcpi_map_2024.png"
)

adjusted_path <- file.path(
  figures_dir,
  "02_rpp_adjusted_pcpi_map_2024.png"
)

ggplot2::ggsave(
  filename = nominal_path,
  plot = nominal_map,
  width = 14,
  height = 8.5,
  dpi = 300,
  bg = "white"
)

ggplot2::ggsave(
  filename = adjusted_path,
  plot = adjusted_map,
  width = 14,
  height = 8.5,
  dpi = 300,
  bg = "white"
)

# Figure 3: direct comparison of the two rankings.

up_or_same <- x[x$rank_change >= 0, ]
up_or_same <- up_or_same[
  order(-up_or_same$rank_change, up_or_same$state),
]

down <- x[x$rank_change < 0, ]
down <- down[
  order(down$rank_change, down$state),
]

rank_data <- rbind(up_or_same, down)

rank_data$group <- ifelse(
  rank_data$rank_change >= 0,
  "Moved up or stayed",
  "Moved down"
)

rank_data$group <- factor(
  rank_data$group,
  levels = c("Moved up or stayed", "Moved down")
)

rank_data$state_order <- factor(
  rank_data$state,
  levels = rev(rank_data$state)
)

rank_data$point_color <- ifelse(
  rank_data$rank_change > 0,
  "up",
  ifelse(
    rank_data$rank_change < 0,
    "down",
    "same"
  )
)

rank_data$change_label <- ifelse(
  rank_data$rank_change > 0,
  paste0("+", rank_data$rank_change),
  as.character(rank_data$rank_change)
)

rank_plot <- ggplot2::ggplot(
  rank_data,
  ggplot2::aes(
    x = rank_change,
    y = state_order,
    color = point_color
  )
) +
  ggplot2::geom_vline(
    xintercept = 0,
    color = "#8A99A8",
    linewidth = 0.45
  ) +
  ggplot2::geom_segment(
    ggplot2::aes(
      x = 0,
      xend = rank_change,
      yend = state_order
    ),
    linewidth = 0.7
  ) +
  ggplot2::geom_point(size = 2.3) +
  ggplot2::geom_text(
    ggplot2::aes(
      x = rank_change + ifelse(
        rank_change < 0,
        -0.55,
        0.55
      ),
      label = change_label,
      hjust = ifelse(rank_change < 0, 1, 0)
    ),
    color = "#344456",
    size = 3.1,
    show.legend = FALSE
  ) +
  ggplot2::facet_wrap(
    ~ group,
    ncol = 2,
    scales = "free_y"
  ) +
  ggplot2::scale_color_manual(
    values = c(
      up = "#176A9A",
      down = "#C65D3B",
      same = "#8595A4"
    ),
    guide = "none"
  ) +
  ggplot2::scale_x_continuous(
    breaks = seq(-30, 20, 10),
    limits = c(-32, 22)
  ) +
  ggplot2::labs(
    title = "How far did states move in the ranking?",
    subtitle = paste(
      "Positive = closer to rank 1;",
      "negative = farther from rank 1 \u00b7 2024"
    ),
    x = "Change in rank after RPP adjustment (places)",
    y = NULL,
    caption = paste(
      "Source: BEA SAINC1, September 26, 2025 release,",
      "and BEA SARPP. 2024 data; D.C. excluded."
    )
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.major.y = ggplot2::element_blank(),
    panel.grid.minor = ggplot2::element_blank(),
    strip.text = ggplot2::element_text(
      face = "bold",
      size = 13
    ),
    axis.text.y = ggplot2::element_text(
      size = 10,
      color = "#344456"
    ),
    axis.title.x = ggplot2::element_text(size = 11),
    plot.title = ggplot2::element_text(
      face = "bold",
      size = 20
    ),
    plot.subtitle = ggplot2::element_text(
      size = 11,
      margin = ggplot2::margin(b = 12)
    ),
    plot.caption = ggplot2::element_text(
      size = 9,
      color = "#667789",
      hjust = 0,
      margin = ggplot2::margin(t = 12)
    ),
    panel.spacing.x = grid::unit(1.5, "cm"),
    plot.margin = ggplot2::margin(18, 22, 18, 22)
  )

rank_path <- file.path(
  figures_dir,
  "03_rank_changes_2024.png"
)

ggplot2::ggsave(
  filename = rank_path,
  plot = rank_plot,
  width = 13,
  height = 11,
  dpi = 300,
  bg = "white"
)

cat("Saved:", nominal_path, "\n")
cat("Saved:", adjusted_path, "\n")
cat("Saved:", rank_path, "\n")