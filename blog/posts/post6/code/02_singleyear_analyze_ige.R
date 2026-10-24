# Blog 06 - Step 2: Estimate the single-year IGE.
# Parent labor income: 1998. Child labor income: 2022.
# R packages: install.packages(c("here", "sandwich"))

if (!requireNamespace("here", quietly = TRUE)) stop("Install R package: here")
if (!requireNamespace("sandwich", quietly = TRUE)) stop("Install R package: sandwich")

input_file <- here::here("blog", "posts", "post6", "data", "processed",
                         "ige_single_year.csv")
result_file <- here::here("blog", "posts", "post6", "data", "processed",
                          "ige_singleyear_results.csv")
figure_file <- here::here("blog", "posts", "post6", "figures",
                          "ige_single_only.png")
if (!file.exists(input_file)) {
  stop("Processed data missing. Run code/01_singleyear_prepare_data.R first.")
}

# Read the parent-child sample from Step 1.
df <- read.csv(input_file)
required <- c("child_fam68", "child_pn", "parent_family_1999",
              "child_age23", "parent_income_1998", "child_income_2022")
if (!all(required %in% names(df))) {
  stop("Processed CSV lacks 1999/2023 variables. Rerun Step 1 first.")
}
if (anyDuplicated(df[c("child_fam68", "child_pn")])) {
  stop("Duplicated child IDs in processed data; check Step 1.")
}
df <- df[complete.cases(df[required]) &
         df$parent_income_1998 > 0 & df$child_income_2022 > 0 &
         df$child_age23 >= 35 & df$child_age23 <= 49, , drop = FALSE]
if (nrow(df) < 8) stop("Insufficient positive-income parent-child observations.")

# IGE is the coefficient on log parent income.
df$log_parent <- log(df$parent_income_1998)
df$log_child <- log(df$child_income_2022)

estimate_ige <- function(data, group_name) {
  n <- nrow(data)
  n_families <- length(unique(data$parent_family_1999))
  result <- data.frame(
    group = group_name, n_children = n, n_parent_families = n_families,
    ige_beta = NA_real_, clustered_se = NA_real_,
    ci95_low = NA_real_, ci95_high = NA_real_, r_squared = NA_real_
  )
  if (n < 8 || n_families < 4 || length(unique(data$log_parent)) < 2) {
    return(result)
  }

  model <- stats::lm(log_child ~ log_parent, data = data)
  # Cluster by the 1999 parent family to account for siblings.
  covariance <- sandwich::vcovCL(
    model, cluster = data$parent_family_1999, type = "HC1"
  )
  beta <- unname(stats::coef(model)["log_parent"])
  se <- sqrt(covariance["log_parent", "log_parent"])
  cutoff <- stats::qt(0.975, df = n_families - 1L)
  result$ige_beta <- beta
  result$clustered_se <- se
  result$ci95_low <- beta - cutoff * se
  result$ci95_high <- beta + cutoff * se
  result$r_squared <- summary(model)$r.squared
  result
}

# Compare estimates by child age group (descriptive only).
results <- do.call(rbind, list(
  estimate_ige(df, "All ages 35-49"),
  estimate_ige(subset(df, child_age23 >= 35 & child_age23 <= 39), "Age 35-39"),
  estimate_ige(subset(df, child_age23 >= 40 & child_age23 <= 44), "Age 40-44"),
  estimate_ige(subset(df, child_age23 >= 45 & child_age23 <= 49), "Age 45-49")
))
write.csv(results, result_file, row.names = FALSE)
print(results, row.names = FALSE)

# Plot age-group estimates and their 95% confidence intervals.
age <- results[2:4, , drop = FALSE]
age <- age[is.finite(age$ige_beta) & is.finite(age$ci95_low) &
           is.finite(age$ci95_high), , drop = FALSE]
if (nrow(age) > 0 && is.finite(results$ige_beta[1])) {
  dir.create(dirname(figure_file), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(figure_file, width = 1200, height = 750, res = 150)
  ys <- range(c(age$ci95_low, age$ci95_high, results$ige_beta[1]))
  if (diff(ys) == 0) ys <- ys + c(-0.1, 0.1)
  x <- seq_len(nrow(age))
  graphics::plot(x, age$ige_beta, pch = 19, xaxt = "n", ylim = ys,
                 xlim = c(0.5, nrow(age) + 0.5),
                 xlab = "Adult child's age in 2023",
                 ylab = "IGE coefficient (95% CI)",
                 main = "Single-year IGE by child age: 1998 / 2022")
  graphics::axis(1, at = x, labels = age$group)
  graphics::arrows(x, age$ci95_low, x, age$ci95_high,
                   angle = 90, code = 3, length = 0.06)
  graphics::abline(h = results$ige_beta[1], lty = 2)
  grDevices::dev.off()
}
