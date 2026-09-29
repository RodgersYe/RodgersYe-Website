# Blog Post 3: CPS Weekly Work Hours
# Blog Post 3：CPS 每周工作时长


# ============================================================
# Create five figures from annual weighted estimates.
# 使用年度加权估计结果生成五张图。
# ============================================================


# ------------------------------------------------------------
# 1. Load packages / 加载程序包
# ------------------------------------------------------------

# Run this once if the packages are not installed.
# 如果尚未安装这些程序包，请先单独运行下面的代码。
# install.packages(c("tidyverse", "here"))

library(tidyverse)


# ------------------------------------------------------------
# 2. Set project-relative paths / 设置项目相对路径
# ------------------------------------------------------------

post_dir <- here::here(
  "blog",
  "posts",
  "post3"
)

input_file <- file.path(
  post_dir,
  "data",
  "processed",
  "annual_age_hours.csv"
)

figures_dir <- file.path(
  post_dir,
  "figures"
)

# Check that the annual estimates are available.
# 检查年度估计结果文件是否存在。

if (!file.exists(input_file)) {
  stop(
    paste0(
      "Cannot find the annual estimates.\n",
      "Run 01_clean_analyze.R first.\n",
      "Expected file: ",
      input_file
    ),
    call. = FALSE
  )
}

dir.create(
  figures_dir,
  recursive = TRUE,
  showWarnings = FALSE
)


# ------------------------------------------------------------
# 3. Read and validate the data / 读取并检查数据
# ------------------------------------------------------------

annual_age_hours <- read_csv(
  input_file,
  show_col_types = FALSE
)

figure_metrics <- c(
  "mean_total_hours",
  "mean_main_hours",
  "mean_other_hours",
  "main_share_pct",
  "other_share_pct"
)

required_columns <- c(
  "YEAR",
  "age_group",
  "months_observed",
  figure_metrics
)

missing_columns <- setdiff(
  required_columns,
  names(annual_age_hours)
)

if (length(missing_columns) > 0) {
  stop(
    paste0(
      "Missing required columns: ",
      paste(missing_columns, collapse = ", ")
    ),
    call. = FALSE
  )
}

# Confirm that plotting variables contain finite numeric values.
# 确认绘图变量均为有限的数值。

numeric_columns <- c(
  "YEAR",
  "months_observed",
  figure_metrics
)

if (!all(map_lgl(
  annual_age_hours[numeric_columns],
  is.numeric
))) {
  stop(
    "Some plotting variables were not imported as numeric.",
    call. = FALSE
  )
}

if (any(map_lgl(
  annual_age_hours[numeric_columns],
  ~ any(!is.finite(.x))
))) {
  stop(
    "Plotting variables contain missing or nonfinite values.",
    call. = FALSE
  )
}

# Set the age-group order consistently across all figures.
# 为所有图表设置一致的年龄组顺序。

age_levels <- c(
  "16-24",
  "25-34",
  "35-44",
  "45-54",
  "55-64",
  "65+"
)

annual_age_hours <- annual_age_hours %>%
  mutate(
    age_group = factor(
      age_group,
      levels = age_levels
    )
  ) %>%
  arrange(age_group, YEAR)

if (anyNA(annual_age_hours$age_group)) {
  stop(
    "Unexpected or missing age-group labels.",
    call. = FALSE
  )
}

# Require all 25 years and six age groups, with one row per cell.
# 要求包含全部 25 年和六个年龄组，每个组合恰好一行。

expected_cells <- expand_grid(
  YEAR = 2000:2024,
  age_group = age_levels
)

missing_cells <- expected_cells %>%
  anti_join(
    annual_age_hours %>%
      mutate(age_group = as.character(age_group)),
    by = c("YEAR", "age_group")
  )

if (
  nrow(annual_age_hours) != nrow(expected_cells) ||
  nrow(missing_cells) > 0
) {
  stop(
    "Expected exactly one observation for each year and age group.",
    call. = FALSE
  )
}

if (any(annual_age_hours$months_observed != 12)) {
  stop(
    "Each annual estimate must contain all 12 months.",
    call. = FALSE
  )
}


# ------------------------------------------------------------
# 4. Define colors and theme / 设置颜色与图表样式
# ------------------------------------------------------------

# Use the same color for each age group in every figure.
# 每个年龄组在所有图表中始终使用同一种颜色。

age_colors <- c(
  "16-24" = "#E69F00",
  "25-34" = "#56B4E9",
  "35-44" = "#009E73",
  "45-54" = "#0072B2",
  "55-64" = "#D55E00",
  "65+"   = "#CC79A7"
)

# Use a simple theme with readable labels and a bottom legend.
# 使用简洁样式、清晰标签和底部图例。

theme_blog <- function() {
  theme_minimal(
    base_size = 12,
    base_family = "sans"
  ) +
    theme(
      plot.title = element_text(
        size = 17,
        face = "bold",
        color = "#202020",
        margin = margin(b = 8)
      ),
      
      plot.subtitle = element_text(
        size = 11,
        color = "#555555",
        margin = margin(b = 14)
      ),
      
      plot.caption = element_text(
        size = 9,
        color = "#666666",
        hjust = 0,
        lineheight = 1.15,
        margin = margin(t = 12)
      ),
      
      plot.title.position = "plot",
      plot.caption.position = "plot",
      
      axis.title = element_text(
        size = 12,
        color = "#333333"
      ),
      
      axis.title.x = element_text(
        margin = margin(t = 10)
      ),
      
      axis.title.y = element_text(
        margin = margin(r = 10)
      ),
      
      axis.text = element_text(
        size = 10,
        color = "#444444"
      ),
      
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      
      panel.grid.major.y = element_line(
        color = "#E5E5E5",
        linewidth = 0.35
      ),
      
      legend.position = "bottom",
      legend.title = element_text(face = "bold"),
      legend.text = element_text(size = 11),
      
      plot.margin = margin(
        t = 15,
        r = 20,
        b = 15,
        l = 15
      )
    )
}


# ------------------------------------------------------------
# 5. Define captions and a plotting function / 定义图注与绘图函数
# ------------------------------------------------------------

source_caption <- paste(
  "Source: IPUMS CPS, Basic Monthly samples, 2000-2024.",
  "Sample: civilians aged 16+ who were at work in the reference week.",
  "Monthly estimates use WTFINL; annual means average the 12 monthly estimates.",
  sep = "\n"
)

# Build a line chart for a specified metric.
# 为指定指标生成折线图。

make_trend_plot <- function(
    metric,
    title,
    subtitle,
    y_label,
    y_limits,
    y_labels,
    note = NULL
) {
  
  # Add a figure-specific note when provided.
  # 如有需要，添加该图专用的说明。
  
  caption_text <- source_caption
  
  if (!is.null(note)) {
    caption_text <- paste(
      source_caption,
      note,
      sep = "\n"
    )
  }
  
  ggplot(
    annual_age_hours,
    aes(
      x = YEAR,
      y = .data[[metric]],
      color = age_group,
      group = age_group
    )
  ) +
    geom_line(
      linewidth = 1
    ) +
    
    # Mark the final-year observations.
    # 标记最后一年的观测值。
    
    geom_point(
      data = annual_age_hours %>%
        filter(YEAR == 2024),
      size = 2.3
    ) +
    
    scale_color_manual(
      values = age_colors,
      breaks = age_levels,
      drop = FALSE,
      name = "Age group"
    ) +
    
    scale_x_continuous(
      breaks = c(
        2000, 2005, 2010,
        2015, 2020, 2024
      ),
      limits = c(2000, 2024),
      expand = expansion(
        mult = c(0.01, 0.02)
      )
    ) +
    
    scale_y_continuous(
      limits = y_limits,
      breaks = scales::breaks_pretty(n = 6),
      labels = y_labels,
      expand = expansion(
        mult = c(0.02, 0.05)
      )
    ) +
    
    guides(
      color = guide_legend(
        nrow = 2,
        byrow = TRUE
      )
    ) +
    
    labs(
      title = title,
      subtitle = subtitle,
      x = "Year",
      y = y_label,
      caption = caption_text
    ) +
    
    theme_blog()
}


# ------------------------------------------------------------
# 6. Define axis ranges / 设置坐标轴范围
# ------------------------------------------------------------

# Give total-hours and main-job-hours plots the same vertical scale.
# 总工时图和主职工时图使用相同的纵轴范围。

combined_hours_range <- range(
  annual_age_hours$mean_total_hours,
  annual_age_hours$mean_main_hours
)

shared_hours_limits <- c(
  floor(combined_hours_range[1] / 5) * 5,
  ceiling(combined_hours_range[2] / 5) * 5
)

# Start other-job hours at zero.
# 其他工作工时的纵轴从零开始。

other_hours_limits <- c(
  0,
  max(
    0.2,
    ceiling(
      max(annual_age_hours$mean_other_hours) / 0.2
    ) * 0.2
  )
)

# Zoom the main-job share axis to show small changes.
# 放大主职工时占比的纵轴，以展示较小的变化。

main_share_range <- range(
  annual_age_hours$main_share_pct
)

main_share_limits <- c(
  floor(main_share_range[1] / 0.25) * 0.25,
  ceiling(main_share_range[2] / 0.25) * 0.25
)

# Start other-job shares at zero.
# 其他工作工时占比的纵轴从零开始。

other_share_limits <- c(
  0,
  max(
    0.5,
    ceiling(
      max(annual_age_hours$other_share_pct) / 0.5
    ) * 0.5
  )
)

# Percentage columns already use a 0-100 scale.
# 百分比变量已经采用 0 到 100 的数值尺度。

percent_labels <- scales::label_percent(
  scale = 1,
  accuracy = 0.1
)


# ------------------------------------------------------------
# 7. Figure 1: Total hours / 图一：总工时
# ------------------------------------------------------------

fig1 <- make_trend_plot(
  metric = "mean_total_hours",
  
  title = "Figure 1. Total weekly work hours by age",
  
  subtitle = "Annual average actual hours across all jobs, 2000-2024",
  
  y_label = "Hours per worker per week",
  
  y_limits = shared_hours_limits,
  
  y_labels = scales::label_number(
    accuracy = 1
  ),
  
  note = paste(
    "The vertical axis is zoomed.",
    "Figures 1 and 2 use the same vertical scale."
  )
)


# ------------------------------------------------------------
# 8. Figure 2: Main-job hours / 图二：主职工时
# ------------------------------------------------------------

fig2 <- make_trend_plot(
  metric = "mean_main_hours",
  
  title = "Figure 2. Main-job weekly work hours by age",
  
  subtitle = "Annual average actual hours at the main job, 2000-2024",
  
  y_label = "Hours per worker per week",
  
  y_limits = shared_hours_limits,
  
  y_labels = scales::label_number(
    accuracy = 1
  ),
  
  note = paste(
    "The vertical axis is zoomed.",
    "Figures 1 and 2 use the same vertical scale."
  )
)


# ------------------------------------------------------------
# 9. Figure 3: Other-job hours / 图三：其他工作工时
# ------------------------------------------------------------

fig3 <- make_trend_plot(
  metric = "mean_other_hours",
  
  title = "Figure 3. Other-job weekly work hours by age",
  
  subtitle = "Average across all workers in the sample, including zeros for single-job workers",
  
  y_label = "Hours per worker per week",
  
  y_limits = other_hours_limits,
  
  y_labels = scales::label_number(
    accuracy = 0.1
  ),
  
  note = "Other-job hours are set to zero for confirmed single-job workers."
)


# ------------------------------------------------------------
# 10. Figure 4: Main-job share / 图四：主职工时占比
# ------------------------------------------------------------

fig4 <- make_trend_plot(
  metric = "main_share_pct",
  
  title = "Figure 4. Main-job share of weekly work hours",
  
  subtitle = "Ratio of annual mean main-job hours to annual mean total hours, by age",
  
  y_label = "Main-job hours / total hours (%)",
  
  y_limits = main_share_limits,
  
  y_labels = percent_labels,
  
  note = "The vertical axis is zoomed and does not start at zero."
)


# ------------------------------------------------------------
# 11. Figure 5: Other-job share / 图五：其他工作工时占比
# ------------------------------------------------------------

fig5 <- make_trend_plot(
  metric = "other_share_pct",
  
  title = "Figure 5. Other-job share of weekly work hours",
  
  subtitle = "Ratio of annual mean other-job hours to annual mean total hours, by age",
  
  y_label = "Other-job hours / total hours (%)",
  
  y_limits = other_share_limits,
  
  y_labels = percent_labels,
  
  note = "Other-job hours include zeros for confirmed single-job workers."
)


# ------------------------------------------------------------
# 12. Save all five figures / 保存全部五张图
# ------------------------------------------------------------

# Use named list entries as the output filenames.
# 使用列表元素名称作为输出文件名。

plots <- list(
  "fig1_total_hours_by_age" = fig1,
  "fig2_main_job_hours_by_age" = fig2,
  "fig3_other_job_hours_by_age" = fig3,
  "fig4_main_job_share_by_age" = fig4,
  "fig5_other_job_share_by_age" = fig5
)

# Export high-resolution PNG files for the blog.
# 导出适用于博客的高分辨率 PNG 图片。

iwalk(
  plots,
  function(plot_object, file_name) {
    
    output_file <- file.path(
      figures_dir,
      paste0(file_name, ".png")
    )
    
    ggsave(
      filename = output_file,
      plot = plot_object,
      device = "png",
      width = 11,
      height = 7,
      units = "in",
      dpi = 300,
      bg = "white"
    )
    
    message("Saved: ", output_file)
  }
)


# ------------------------------------------------------------
# 13. Display the figures / 显示图表
# ------------------------------------------------------------

# Print every figure to the RStudio plot history.
# 将所有图表依次显示在 RStudio 的绘图历史中。

walk(
  plots,
  print
)

cat(
  "\nAll five figures have been saved to: ",
  figures_dir,
  "\n",
  sep = ""
)