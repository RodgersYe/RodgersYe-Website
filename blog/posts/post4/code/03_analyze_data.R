# Blog Post 4 — 03_analyze_data.R
# Calculate price-adjusted income and compare state rankings.

if (!requireNamespace("here", quietly = TRUE)) {
  stop("Install the 'here' package first: install.packages('here')")
}

processed_dir <- here::here(
  "blog", "posts", "post4", "data", "processed"
)

input_path <- file.path(
  processed_dir,
  "state_income_prices_2024.csv"
)

if (!file.exists(input_path)) {
  stop("Run 02_clean_data.R before this script.")
}

x <- utils::read.csv(
  input_path,
  colClasses = c(GeoFips = "character"),
  stringsAsFactors = FALSE
)

required <- c(
  "GeoFips", "state", "year",
  "nominal_pcpi", "rpp_all_items",
  "official_real_pcpi"
)

if (
  !all(required %in% names(x)) ||
  nrow(x) != 50 ||
  !setequal(x$state, state.name) ||
  !all(as.character(x$year) == "2024") ||
  anyNA(x) ||
  anyDuplicated(x[c("GeoFips", "year")]) > 0
) {
  stop("The processed input failed the 50-state validation.")
}

numeric_columns <- c(
  "nominal_pcpi",
  "rpp_all_items",
  "official_real_pcpi"
)

if (
  !all(vapply(x[numeric_columns], is.numeric, logical(1))) ||
  any(!is.finite(as.matrix(x[numeric_columns]))) ||
  any(as.matrix(x[numeric_columns]) <= 0)
) {
  stop("Income and RPP values must be positive numeric values.")
}

# RPP = 100 represents the national average price level.
# This adjustment compares purchasing power across states in 2024.
# It does not convert income into constant 2017 dollars.
x$adjusted_pcpi <- x$nominal_pcpi /
  (x$rpp_all_items / 100)

# Rank 1 has the highest income. Exact ties share the better rank.
x$nominal_rank <- rank(
  -x$nominal_pcpi,
  ties.method = "min"
)

x$adjusted_rank <- rank(
  -x$adjusted_pcpi,
  ties.method = "min"
)

# Positive rank change means a state moves UP after adjustment.
# Example: nominal rank 20, adjusted rank 12 -> +8.
x$rank_change <- x$nominal_rank - x$adjusted_rank

# Official real PCPI is measured in constant 2017 dollars.
# Use its ranking to validate the cross-state comparison.
x$official_real_rank <- rank(
  -x$official_real_pcpi,
  ties.method = "min"
)

x$official_to_adjusted_ratio <-
  x$official_real_pcpi / x$adjusted_pcpi

rank_disagreements <- sum(
  x$adjusted_rank != x$official_real_rank
)

ratio_range <- range(
  x$official_to_adjusted_ratio
)

# These checks apply to the fixed 2024 source vintages in this project.
# They prevent a later API revision from silently changing the analysis.
if (rank_disagreements != 0) {
  stop(
    "Adjusted ranks differ from BEA's official real PCPI ranks ",
    "for ", rank_disagreements, " states. ",
    "Check whether the raw files come from matching releases."
  )
}

if (diff(ratio_range) > 0.0001) {
  stop(
    "The official-to-adjusted ratio varies more than expected. ",
    "Check the income, RPP, and real PCPI source vintages."
  )
}

nominal_top10 <- x$state[x$nominal_rank <= 10]
adjusted_top10 <- x$state[x$adjusted_rank <= 10]

summary_metrics <- data.frame(
  year = 2024,
  states = nrow(x),
  states_moving_up = sum(x$rank_change > 0),
  states_moving_down = sum(x$rank_change < 0),
  states_unchanged = sum(x$rank_change == 0),
  states_with_rank_change = sum(x$rank_change != 0),
  median_absolute_rank_change = median(abs(x$rank_change)),
  maximum_absolute_rank_change = max(abs(x$rank_change)),
  nominal_top10_count = length(nominal_top10),
  adjusted_top10_count = length(adjusted_top10),
  top10_overlap = length(intersect(
    nominal_top10,
    adjusted_top10
  )),
  income_rpp_correlation = cor(
    x$nominal_pcpi,
    x$rpp_all_items
  ),
  official_rank_disagreements = rank_disagreements,
  official_ratio_min = ratio_range[1],
  official_ratio_max = ratio_range[2]
)

x <- x[
  order(x$state),
  c(
    "GeoFips", "state", "year",
    "nominal_pcpi", "rpp_all_items",
    "adjusted_pcpi", "official_real_pcpi",
    "nominal_rank", "adjusted_rank",
    "rank_change", "official_real_rank",
    "official_to_adjusted_ratio"
  )
]

analysis_path <- file.path(
  processed_dir,
  "state_income_analysis_2024.csv"
)

summary_path <- file.path(
  processed_dir,
  "rank_summary_2024.csv"
)

utils::write.csv(
  x,
  analysis_path,
  row.names = FALSE
)

utils::write.csv(
  summary_metrics,
  summary_path,
  row.names = FALSE
)

cat("\nSummary metrics:\n")
print(summary_metrics, row.names = FALSE)

cat("\nHighest nominal PCPI:\n")
nominal_leaders <- x[
  x$nominal_rank <= 10,
  c("state", "nominal_pcpi", "nominal_rank")
]
print(
  nominal_leaders[
    order(nominal_leaders$nominal_rank,
          nominal_leaders$state),
  ],
  row.names = FALSE
)

cat("\nHighest RPP-adjusted PCPI:\n")
adjusted_leaders <- x[
  x$adjusted_rank <= 10,
  c("state", "adjusted_pcpi", "adjusted_rank")
]
print(
  adjusted_leaders[
    order(adjusted_leaders$adjusted_rank,
          adjusted_leaders$state),
  ],
  row.names = FALSE
)

cat("\nLargest upward rank changes (positive = up):\n")
print(
  head(
    x[
      order(-x$rank_change, x$state),
      c(
        "state", "nominal_rank",
        "adjusted_rank", "rank_change",
        "rpp_all_items"
      )
    ],
    5
  ),
  row.names = FALSE
)

cat("\nLargest downward rank changes:\n")
print(
  head(
    x[
      order(x$rank_change, x$state),
      c(
        "state", "nominal_rank",
        "adjusted_rank", "rank_change",
        "rpp_all_items"
      )
    ],
    5
  ),
  row.names = FALSE
)

cat("\nOfficial real PCPI rank check: passed (0 differences).\n")
cat(
  "Official-to-adjusted ratio range:",
  sprintf("%.6f", ratio_range[1]),
  "to",
  sprintf("%.6f", ratio_range[2]),
  "\n"
)

cat(
  "\nSaved:\n",
  analysis_path,
  "\n",
  summary_path,
  "\n"
)