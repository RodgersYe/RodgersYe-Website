# Blog 06 | Step 4: multi-year IGE and same-sample single-year comparison.
# Run 03_multiyear_prepare_data.R first. One-time setup:
# install.packages(c("here", "sandwich"))

if (!requireNamespace("here", quietly = TRUE)) stop("Install R package: here")
if (!requireNamespace("sandwich", quietly = TRUE)) stop("Install R package: sandwich")

input_file <- here::here("blog", "posts", "post6", "data", "processed", "ige_multi_year.csv")
results_file <- here::here("blog", "posts", "post6", "data", "processed", "ige_multiyear_results.csv")
difference_file <- here::here("blog", "posts", "post6", "data", "processed", "ige_multiyear_difference.csv")
figure_file <- here::here("blog", "posts", "post6", "figures", "ige_single_vs_multiyear.png")
multiyear_figure_file <- here::here("blog", "posts", "post6", "figures", "ige_multiyear_only.png")

if (!file.exists(input_file)) stop("Run 03_multiyear_prepare_data.R first")
df <- read.csv(input_file)
required <- c("child_fam68", "child_pn", "parent_family_1999", "child_age23",
              "parent_income_1998", "child_income_2022",
              "parent_avg_2022usd", "child_avg_2022usd",
              "n_parent_years", "n_child_years")
if (!all(required %in% names(df))) stop("Missing columns in ige_multi_year.csv")
if (anyDuplicated(df[c("child_fam68", "child_pn")])) stop("Duplicate child identifiers")

df <- df[stats::complete.cases(df[, required]) &
           df$parent_income_1998 > 0 & df$child_income_2022 > 0 &
           df$parent_avg_2022usd > 0 & df$child_avg_2022usd > 0 &
           df$child_age23 >= 35 & df$child_age23 <= 49, , drop = FALSE]
if (nrow(df) < 8L) stop("Too few complete matched observations")

# Log of average REAL incomes (2022 dollars); never average logged earnings.
df$ln_parent_single <- log(df$parent_income_1998)
df$ln_child_single <- log(df$child_income_2022)
df$ln_parent_multi <- log(df$parent_avg_2022usd)
df$ln_child_multi <- log(df$child_avg_2022usd)

estimate_ige <- function(data, group, measure) {
  p <- if (measure == "Single-year") "ln_parent_single" else "ln_parent_multi"
  c <- if (measure == "Single-year") "ln_child_single" else "ln_child_multi"
  n_family <- length(unique(data$parent_family_1999))
  result <- data.frame(group = group, measure = measure, n_children = nrow(data),
                       n_parent_families = n_family, ige_beta = NA_real_,
                       clustered_se = NA_real_, ci95_low = NA_real_,
                       ci95_high = NA_real_, r_squared = NA_real_)
  if (nrow(data) < 8L || n_family < 4L || length(unique(data[[p]])) < 2L) return(result)

  model <- stats::lm(stats::reformulate(p, response = c), data = data)
  # Cluster siblings' regression errors at their shared 1999 parental family.
  vc <- sandwich::vcovCL(model, cluster = data$parent_family_1999, type = "HC1")
  beta <- unname(stats::coef(model)[p])
  se <- sqrt(vc[p, p])
  critical <- stats::qt(0.975, df = n_family - 1L)
  result$ige_beta <- beta
  result$clustered_se <- se
  result$ci95_low <- beta - critical * se
  result$ci95_high <- beta + critical * se
  result$r_squared <- summary(model)$r.squared
  result
}

# Same children in both models, including within each age subgroup.
groups <- list(
  "All ages 35-49" = df,
  "Age 35-39" = subset(df, child_age23 >= 35 & child_age23 <= 39),
  "Age 40-44" = subset(df, child_age23 >= 40 & child_age23 <= 44),
  "Age 45-49" = subset(df, child_age23 >= 45 & child_age23 <= 49)
)
results <- do.call(rbind, lapply(names(groups), function(label) {
  rbind(estimate_ige(groups[[label]], label, "Single-year"),
        estimate_ige(groups[[label]], label, "Multi-year"))
}))
row.names(results) <- NULL
write.csv(results, results_file, row.names = FALSE)
print(results, row.names = FALSE)

# life-cycle bias.
full_single <- results$ige_beta[1L]
full_multi <- results$ige_beta[2L]
delta <- full_single - full_multi
cluster_rows <- split(seq_len(nrow(df)), as.character(df$parent_family_1999))
set.seed(6400)
B <- 499L
boot_delta <- replicate(B, {
  selected <- sample(seq_along(cluster_rows), length(cluster_rows), replace = TRUE)
  sample_rows <- unlist(cluster_rows[selected], use.names = FALSE)
  d <- df[sample_rows, , drop = FALSE]
  b1 <- unname(stats::coef(stats::lm(ln_child_single ~ ln_parent_single, data = d))[2L])
  b2 <- unname(stats::coef(stats::lm(ln_child_multi ~ ln_parent_multi, data = d))[2L])
  b1 - b2
})
boot_delta <- boot_delta[is.finite(boot_delta)]
if (length(boot_delta) < B * 0.90) stop("Too many unsuccessful cluster-bootstrap draws")
ci_delta <- unname(stats::quantile(boot_delta, c(0.025, 0.975)))
difference <- data.frame(n_children = nrow(df),
                         n_parent_families = length(cluster_rows),
                         beta_single = full_single, beta_multi = full_multi,
                         single_minus_multi = delta,
                         bootstrap_se = stats::sd(boot_delta),
                         ci95_low = ci_delta[1L], ci95_high = ci_delta[2L],
                         min_parent_waves = min(df$n_parent_years),
                         median_parent_waves = stats::median(df$n_parent_years),
                         min_child_waves = min(df$n_child_years),
                         median_child_waves = stats::median(df$n_child_years))
write.csv(difference, difference_file, row.names = FALSE)

# Plot multi-year age-group estimates and their 95% confidence intervals.
multi <- results[results$measure == "Multi-year", , drop = FALSE]
age <- multi[2:4, , drop = FALSE]
age <- age[is.finite(age$ige_beta) & is.finite(age$ci95_low) &
             is.finite(age$ci95_high), , drop = FALSE]
if (nrow(age) > 0 && is.finite(multi$ige_beta[1])) {
  dir.create(dirname(multiyear_figure_file), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(multiyear_figure_file, width = 1200, height = 750, res = 150)
  ys <- range(c(age$ci95_low, age$ci95_high, multi$ige_beta[1]))
  if (diff(ys) == 0) ys <- ys + c(-0.1, 0.1)
  x <- seq_len(nrow(age))
  graphics::plot(x, age$ige_beta, pch = 19, xaxt = "n", ylim = ys,
                 xlim = c(0.5, nrow(age) + 0.5),
                 xlab = "Adult child's age in 2023",
                 ylab = "IGE coefficient (95% CI)",
                 main = "Multi-year IGE by child age")
  graphics::axis(1, at = x, labels = age$group)
  graphics::arrows(x, age$ci95_low, x, age$ci95_high,
                   angle = 90, code = 3, length = 0.06)
  graphics::abline(h = multi$ige_beta[1], lty = 2)
  grDevices::dev.off()
}

# Show both models and confidence intervals side by side for each age group.
plot_results <- results[is.finite(results$ige_beta) & is.finite(results$ci95_low) &
                          is.finite(results$ci95_high), , drop = FALSE]
if (nrow(plot_results) > 0L) {
  dir.create(dirname(figure_file), showWarnings = FALSE, recursive = TRUE)
  grDevices::png(figure_file, width = 1250, height = 780, res = 150)
  order_groups <- names(groups)
  x <- match(plot_results$group, order_groups) +
    ifelse(plot_results$measure == "Single-year", -0.13, 0.13)
  ylim <- range(c(0, plot_results$ci95_low, plot_results$ci95_high), finite = TRUE)
  graphics::plot(x, plot_results$ige_beta, type = "n", xlim = c(0.5, 4.5),
                 ylim = ylim, xaxt = "n", xlab = "Child age in 2023",
                 ylab = "IGE coefficient (95% clustered CI)",
                 main = "Single-year vs multi-year IGE (common sample)")
  graphics::axis(1, at = seq_along(order_groups), labels = order_groups)
  single <- plot_results$measure == "Single-year"
  graphics::points(x[single], plot_results$ige_beta[single], pch = 16)
  graphics::points(x[!single], plot_results$ige_beta[!single], pch = 17)
  graphics::arrows(x, plot_results$ci95_low, x, plot_results$ci95_high,
                   angle = 90, code = 3, length = 0.05)
  graphics::legend("topright", legend = c("Single-year", "Multi-year"),
                   pch = c(16, 17), bty = "n")
  grDevices::dev.off()
}
