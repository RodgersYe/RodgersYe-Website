# Blog Post 3: CPS Weekly Work Hours
# Blog Post 3：CPS 每周工作时长


# ============================================================
# Stage 1: Import and audit the raw data
# 第一阶段：导入并检查原始数据
# ============================================================


# ------------------------------------------------------------
# 1. Load packages / 加载程序包
# ------------------------------------------------------------

# Run this once if the packages are not installed.
# 如果尚未安装这些程序包，请先单独运行下面的代码。
# install.packages(c("tidyverse", "here"))

library(tidyverse)


# ------------------------------------------------------------
# 2. Set project-relative paths / 设置相对于项目根目录的路径
# ------------------------------------------------------------

# Locate the website project root.
# 定位整个网站项目的根目录。

project_root <- here::here()

# Locate the Blog Post 3 directory within the website project.
# 定位网站项目内的 Blog Post 3 文件夹。

post_dir <- here::here(
  "blog",
  "posts",
  "post3"
)

# Define input and output paths relative to the Blog Post 3 directory.
# 根据 Blog Post 3 文件夹的位置定义输入和输出路径。

raw_file <- file.path(
  post_dir,
  "data",
  "raw",
  "cps_raw.csv"
)

processed_dir <- file.path(
  post_dir,
  "data",
  "processed"
)

# Check that the raw data file exists.
# 检查原始数据文件是否存在。

if (!file.exists(raw_file)) {
  stop(
    paste0(
      "Cannot find the raw data file.\n",
      "Expected project-relative path: ",
      "blog/posts/post3/data/raw/cps_raw.csv\n\n",
      "Detected project root: ", project_root, "\n",
      "Resolved input path: ", raw_file
    ),
    call. = FALSE
  )
}

# Create the processed-data directory if needed.
# 如果处理后数据的文件夹不存在，则创建该文件夹。

dir.create(
  processed_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Display the resolved paths.
# 显示实际使用的输入和输出路径。

message("Raw data file: ", raw_file)
message("Processed data directory: ", processed_dir)


# ------------------------------------------------------------
# 3. Import the raw data / 导入原始数据
# ------------------------------------------------------------

# Preserve IPUMS numeric codes such as 999 during the audit.
# 检查阶段保留 999 等 IPUMS 数值代码，暂不将其转换为缺失值。

cps_raw <- read_csv(
  raw_file,
  show_col_types = FALSE
)

# Stop if the input file contains no observations.
# 如果输入文件没有任何观测记录，则停止运行。

if (nrow(cps_raw) == 0) {
  stop(
    "The input file contains no observations.",
    call. = FALSE
  )
}


# ------------------------------------------------------------
# 4. Check required variables / 检查必需变量
# ------------------------------------------------------------

required_variables <- c(
  "YEAR",
  "MONTH",
  "AGE",
  "WTFINL",
  "EMPSTAT",
  "MULTJOB",
  "AHRSWORKT",
  "AHRSWORK1",
  "AHRSWORK2"
)

missing_variables <- setdiff(
  required_variables,
  names(cps_raw)
)

if (length(missing_variables) > 0) {
  stop(
    paste0(
      "Missing required columns: ",
      paste(missing_variables, collapse = ", ")
    ),
    call. = FALSE
  )
}

# Confirm that the required variables were imported as numeric.
# 确认必需变量均被读取为数值类型。

nonnumeric_variables <- required_variables[
  !map_lgl(cps_raw[required_variables], is.numeric)
]

if (length(nonnumeric_variables) > 0) {
  stop(
    paste0(
      "Expected numeric columns, but found other types: ",
      paste(nonnumeric_variables, collapse = ", "),
      ". Check the CSV format before proceeding."
    ),
    call. = FALSE
  )
}


# ------------------------------------------------------------
# 5. Create a variable inventory / 创建变量清单
# ------------------------------------------------------------

# Count actual missing values; IPUMS special codes remain separate.
# 统计实际缺失值；IPUMS 特殊数值代码暂时单独处理。

data_inventory <- tibble(
  variable = names(cps_raw),
  data_type = map_chr(
    cps_raw,
    ~ paste(class(.x), collapse = ", ")
  ),
  missing_n = map_int(
    cps_raw,
    ~ sum(is.na(.x))
  )
)

write_csv(
  data_inventory,
  file.path(processed_dir, "data_inventory.csv")
)


# ------------------------------------------------------------
# 6. Check year and month coverage / 检查年份和月份覆盖
# ------------------------------------------------------------

# These counts describe sample records, not population estimates.
# 这些数量描述样本记录数，不代表加权后的总体人数。

year_month_audit <- cps_raw %>%
  count(
    YEAR,
    MONTH,
    name = "sample_rows"
  ) %>%
  arrange(YEAR, MONTH)

write_csv(
  year_month_audit,
  file.path(processed_dir, "year_month_audit.csv")
)

# Identify missing months within the planned study period.
# 检查计划研究区间内是否缺少月份。

expected_months <- expand_grid(
  YEAR = 2000:2024,
  MONTH = 1:12
)

missing_months <- expected_months %>%
  anti_join(
    year_month_audit,
    by = c("YEAR", "MONTH")
  )

write_csv(
  missing_months,
  file.path(processed_dir, "missing_months_audit.csv")
)


# ------------------------------------------------------------
# 7. Inspect employment-related codes / 检查就业相关变量编码
# ------------------------------------------------------------

# Check these codes against the IPUMS extract codebook.
# 请将这些编码与本次 IPUMS 提取文件的代码本进行核对。

empstat_audit <- cps_raw %>%
  count(
    EMPSTAT,
    sort = TRUE,
    name = "sample_rows"
  )

multjob_audit <- cps_raw %>%
  count(
    MULTJOB,
    sort = TRUE,
    name = "sample_rows"
  )


write_csv(
  empstat_audit,
  file.path(processed_dir, "empstat_code_audit.csv")
)

write_csv(
  multjob_audit,
  file.path(processed_dir, "multjob_code_audit.csv")
)


# ------------------------------------------------------------
# 8. Inspect hours codes / 检查工时变量编码
# ------------------------------------------------------------

# Return NA if a variable has no nonmissing values.
# 如果某变量全部缺失，则返回 NA。

safe_min <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  
  min(x, na.rm = TRUE)
}

safe_max <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  
  max(x, na.rm = TRUE)
}

# The value 999 indicates NIU in these hours variables.
# 这些工时变量中的 999 表示不在该变量的适用范围内。

# The value 99 represents 99 or more hours in AHRSWORK1 and AHRSWORK2.
# AHRSWORK1 和 AHRSWORK2 中的 99 表示 99 小时或以上。

hours_audit <- cps_raw %>%
  summarise(
    ahrsworkt_niu_999_n = sum(
      AHRSWORKT == 999,
      na.rm = TRUE
    ),
    ahrswork1_niu_999_n = sum(
      AHRSWORK1 == 999,
      na.rm = TRUE
    ),
    ahrswork2_niu_999_n = sum(
      AHRSWORK2 == 999,
      na.rm = TRUE
    ),
    ahrswork1_topcode_99_n = sum(
      AHRSWORK1 == 99,
      na.rm = TRUE
    ),
    ahrswork2_topcode_99_n = sum(
      AHRSWORK2 == 99,
      na.rm = TRUE
    ),
    across(
      c(AHRSWORKT, AHRSWORK1, AHRSWORK2),
      list(
        missing_n = ~ sum(is.na(.x)),
        min = ~ safe_min(.x),
        max = ~ safe_max(.x)
      ),
      .names = "{.col}_{.fn}"
    )
  )

write_csv(
  hours_audit,
  file.path(processed_dir, "hours_code_audit.csv")
)


# ------------------------------------------------------------
# 9. Inspect sampling weights / 检查抽样权重
# ------------------------------------------------------------

weight_audit <- cps_raw %>%
  summarise(
    sample_rows = n(),
    missing_weight_n = sum(is.na(WTFINL)),
    zero_weight_n = sum(WTFINL == 0, na.rm = TRUE),
    negative_weight_n = sum(WTFINL < 0, na.rm = TRUE),
    minimum_weight = safe_min(WTFINL),
    maximum_weight = safe_max(WTFINL)
  )

write_csv(
  weight_audit,
  file.path(processed_dir, "weight_audit.csv")
)


# ------------------------------------------------------------
# 10. Display audit results / 显示检查结果
# ------------------------------------------------------------

coverage_summary <- year_month_audit %>%
  summarise(
    first_year = safe_min(YEAR),
    last_year = safe_max(YEAR),
    observed_year_month_pairs = n(),
    total_sample_rows = sum(sample_rows)
  )

cat("\n--- Variable inventory ---\n")
print(data_inventory, n = Inf)

cat("\n--- Time coverage ---\n")
print(coverage_summary)

cat("\n--- Missing months within 2000-2024 ---\n")
print(missing_months, n = Inf)

cat("\n--- EMPSTAT codes ---\n")
print(empstat_audit, n = Inf)

cat("\n--- MULTJOB codes ---\n")
print(multjob_audit, n = Inf)

cat("\n--- Hours codes ---\n")
print(hours_audit, width = Inf)

cat("\n--- Sampling weights ---\n")
print(weight_audit, width = Inf)

# Display the actual output directory.
# 显示实际的输出文件夹位置。

cat(
  "\nAudit completed. Outputs saved to: ",
  processed_dir,
  "\n",
  sep = ""
)


# ============================================================
# Stage 2: Clean the data and calculate weighted estimates
# 第二阶段：清理数据并计算加权统计量
# ============================================================


# ------------------------------------------------------------
# 11. Check sample types / 检查样本类型
# ------------------------------------------------------------

# ASECFLAG distinguishes ASEC from March Basic records.
# ASECFLAG 用于区分 ASEC 与三月基础月度样本。

if (!"ASECFLAG" %in% names(cps_raw)) {
  stop(
    "ASECFLAG is required here to check the sample types.",
    call. = FALSE
  )
}

asec_audit <- cps_raw %>%
  count(MONTH, ASECFLAG, name = "sample_rows") %>%
  arrange(MONTH, ASECFLAG)

write_csv(
  asec_audit,
  file.path(processed_dir, "asec_flag_audit.csv")
)

# Check the observed nonmissing flag values.
# 检查实际出现的非缺失标记值。

if (any(
  !is.na(cps_raw$ASECFLAG) &
  !cps_raw$ASECFLAG %in% c(1, 2)
)) {
  stop(
    "Unexpected ASECFLAG codes. Inspect asec_flag_audit.csv.",
    call. = FALSE
  )
}

# ASECFLAG: 1 = ASEC; 2 = March Basic.
# ASECFLAG：1 表示 ASEC；2 表示三月基础月度样本。

# Missing flags in other months are retained.
# 保留其他月份中该标记为空的月度记录。

basic_coverage <- cps_raw %>%
  filter(
    YEAR %in% 2000:2024,
    MONTH %in% 1:12,
    is.na(ASECFLAG) | ASECFLAG == 2
  ) %>%
  count(YEAR, MONTH, name = "sample_rows")

missing_basic_months <- expand_grid(
  YEAR = 2000:2024,
  MONTH = 1:12
) %>%
  anti_join(
    basic_coverage,
    by = c("YEAR", "MONTH")
  )

if (nrow(missing_basic_months) > 0) {
  print(missing_basic_months, n = Inf)
  
  stop(
    "Some Basic Monthly samples are missing after excluding ASEC.",
    call. = FALSE
  )
}


# ------------------------------------------------------------
# 12. Select the target sample / 筛选目标样本
# ------------------------------------------------------------

# Keep only variables needed for this stage to reduce memory use.
# 仅保留本阶段需要的变量，以减少内存占用。

# EMPSTAT = 10 identifies respondents who were at work.
# EMPSTAT = 10 表示调查参考周实际在工作的人。

workers <- cps_raw %>%
  select(
    YEAR, MONTH, ASECFLAG, AGE, WTFINL,
    EMPSTAT, MULTJOB,
    AHRSWORKT, AHRSWORK1, AHRSWORK2
  ) %>%
  filter(
    YEAR %in% 2000:2024,
    MONTH %in% 1:12,
    is.na(ASECFLAG) | ASECFLAG == 2,
    is.finite(AGE),
    AGE >= 16,
    AGE < 999,
    EMPSTAT == 10,
    is.finite(WTFINL),
    WTFINL > 0
  ) %>%
  select(-ASECFLAG, -EMPSTAT)

target_sample_rows <- nrow(workers)

if (target_sample_rows == 0) {
  stop(
    "No observations remain after selecting the target sample.",
    call. = FALSE
  )
}


# ------------------------------------------------------------
# 13. Clean hours and define age groups / 清理工时并划分年龄组
# ------------------------------------------------------------

# Keep valid published hours values, including topcoded values.
# 保留有效的公开工时值，包括达到上限编码的记录。

# AHRSWORKT can reach 198 in the Basic Monthly data.
# 基础月度数据中的 AHRSWORKT 可达到 198。

# Values above 168 are flagged for review rather than silently removed.
# 对超过 168 小时的记录进行标记，以便检查。

workers <- workers %>%
  mutate(
    age_group = cut(
      AGE,
      breaks = c(16, 25, 35, 45, 55, 65, Inf),
      labels = c(
        "16-24", "25-34", "35-44",
        "45-54", "55-64", "65+"
      ),
      right = FALSE
    ),
    
    total_hours = if_else(
      AHRSWORKT %in% 1:198,
      AHRSWORKT,
      NA_real_
    ),
    
    main_hours = if_else(
      AHRSWORK1 %in% 0:99,
      AHRSWORK1,
      NA_real_
    ),
    
    # MULTJOB: 1 = No; 2 = Yes; 0 = NIU.
    # MULTJOB：1 表示没有多份工作；2 表示有；0 表示 NIU。
    
    other_hours = case_when(
      MULTJOB == 1 & AHRSWORK2 %in% c(0, 999) ~ 0,
      MULTJOB == 2 & AHRSWORK2 %in% 0:99 ~ AHRSWORK2,
      TRUE ~ NA_real_
    ),
    
    multiple_jobs = MULTJOB == 2,
    
    single_job_conflict =
      MULTJOB == 1 & AHRSWORK2 %in% 1:99,
    
    total_over_168 = AHRSWORKT %in% 169:198,
    
    main_topcoded = AHRSWORK1 == 99,
    other_topcoded = AHRSWORK2 == 99,
    
    valid_hours =
      !is.na(total_hours) &
      !is.na(main_hours) &
      !is.na(other_hours)
  )


# ------------------------------------------------------------
# 14. Audit cleaning decisions / 检查清理结果
# ------------------------------------------------------------

# Use a common complete-hours sample for all five figures.
# 五张图统一使用三种工时均有效的共同样本。

cleaning_audit <- workers %>%
  group_by(YEAR, age_group) %>%
  summarise(
    target_sample_rows = n(),
    retained_sample_rows = sum(valid_hours),
    excluded_sample_rows = sum(!valid_hours),
    
    invalid_total_hours_n = sum(is.na(total_hours)),
    invalid_main_hours_n = sum(is.na(main_hours)),
    invalid_other_hours_n = sum(is.na(other_hours)),
    
    single_job_conflict_n = sum(
      single_job_conflict,
      na.rm = TRUE
    ),
    
    retained_weight_pct = 100 *
      sum(WTFINL[valid_hours]) / sum(WTFINL),
    
    .groups = "drop"
  )

write_csv(
  cleaning_audit,
  file.path(processed_dir, "cleaning_audit.csv")
)

# Record the overall sample flow.
# 记录总体样本筛选过程。

sample_flow <- tibble(
  stage = c(
    "Raw input records",
    "Basic Monthly records in 2000-2024",
    "Workers at work aged 16+ with positive weights",
    "Common sample with valid hours"
  ),
  sample_rows = c(
    nrow(cps_raw),
    sum(basic_coverage$sample_rows),
    target_sample_rows,
    sum(workers$valid_hours)
  )
)

write_csv(
  sample_flow,
  file.path(processed_dir, "sample_flow.csv")
)

workers <- workers %>%
  filter(valid_hours) %>%
  mutate(
    hours_gap = total_hours - main_hours - other_hours
  )

if (nrow(workers) == 0) {
  stop(
    "No observations remain after cleaning the hours variables.",
    call. = FALSE
  )
}

# Check whether the reported components add up to total hours.
# 检查报告的主职与其他工作工时之和是否等于总工时。

# Preserve the original reported values when inconsistencies occur.
# 出现不一致时保留原始报告值，并记录不一致情况。

consistency_audit <- workers %>%
  group_by(YEAR, age_group) %>%
  summarise(
    sample_rows = n(),
    
    inconsistent_hours_n = sum(
      abs(hours_gap) > 1e-8
    ),
    
    inconsistent_hours_weight_pct = 100 *
      weighted.mean(
        abs(hours_gap) > 1e-8,
        WTFINL
      ),
    
    mean_hours_gap = weighted.mean(
      hours_gap,
      WTFINL
    ),
    
    total_over_168_n = sum(total_over_168),
    main_topcoded_n = sum(main_topcoded),
    other_topcoded_n = sum(other_topcoded),
    
    .groups = "drop"
  )

write_csv(
  consistency_audit,
  file.path(processed_dir, "hours_consistency_audit.csv")
)


# ------------------------------------------------------------
# 15. Calculate monthly weighted statistics / 计算月度加权统计量
# ------------------------------------------------------------

# Calculate the weighted standard deviation of individual hours.
# 计算个体工时分布的加权标准差。

# This describes dispersion and is not a survey standard error.
# 该指标描述工时离散程度，并非抽样估计的标准误。

weighted_sd <- function(x, w) {
  weighted_mean <- weighted.mean(x, w)
  
  sqrt(
    sum(w * (x - weighted_mean)^2) / sum(w)
  )
}

monthly_age_hours <- workers %>%
  group_by(YEAR, MONTH, age_group) %>%
  summarise(
    sample_rows = n(),
    multiple_job_sample_rows = sum(multiple_jobs),
    
    # This is the estimated population represented by retained records.
    # 这是保留记录所代表的月度总体人数估计。
    
    weighted_workers = sum(WTFINL),
    
    mean_total_hours = weighted.mean(
      total_hours, WTFINL
    ),
    
    mean_main_hours = weighted.mean(
      main_hours, WTFINL
    ),
    
    mean_other_hours = weighted.mean(
      other_hours, WTFINL
    ),
    
    sd_total_hours = weighted_sd(
      total_hours, WTFINL
    ),
    
    sd_main_hours = weighted_sd(
      main_hours, WTFINL
    ),
    
    sd_other_hours = weighted_sd(
      other_hours, WTFINL
    ),
    
    multiple_job_pct = 100 *
      weighted.mean(multiple_jobs, WTFINL),
    
    .groups = "drop"
  ) %>%
  mutate(
    main_share_pct = 100 *
      mean_main_hours / mean_total_hours,
    
    other_share_pct = 100 *
      mean_other_hours / mean_total_hours,
    
    share_sum_pct = main_share_pct + other_share_pct
  ) %>%
  arrange(YEAR, MONTH, age_group)

# Require all six age groups in all 300 study months.
# 要求全部 300 个月都包含六个年龄组。

expected_cells <- expand_grid(
  YEAR = 2000:2024,
  MONTH = 1:12,
  age_group = levels(workers$age_group)
)

missing_cells <- expected_cells %>%
  anti_join(
    monthly_age_hours %>%
      mutate(age_group = as.character(age_group)),
    by = c("YEAR", "MONTH", "age_group")
  )

if (nrow(missing_cells) > 0) {
  print(missing_cells, n = Inf)
  
  stop(
    "Some month-by-age-group cells have no valid observations.",
    call. = FALSE
  )
}

write_csv(
  monthly_age_hours,
  file.path(processed_dir, "monthly_age_hours.csv")
)


# ------------------------------------------------------------
# 16. Calculate annual estimates / 计算年度统计量
# ------------------------------------------------------------

# Give each monthly estimate equal weight within a year.
# 同一年内各月估计值采用相等权重。

# Calculate monthly sample-size statistics before replacing sample_rows.
# 在覆盖 sample_rows 之前，先计算月度样本量统计。

annual_age_hours <- monthly_age_hours %>%
  group_by(YEAR, age_group) %>%
  summarise(
    months_observed = n(),
    
    minimum_monthly_sample_rows = min(sample_rows),
    maximum_monthly_sample_rows = max(sample_rows),
    average_monthly_sample_rows = mean(sample_rows),
    
    # Count person-month observations rather than unique individuals.
    # 统计人次观测记录，而不是去重后的个人数量。
    
    sample_rows = sum(sample_rows),
    
    average_monthly_weighted_workers =
      mean(weighted_workers),
    
    mean_total_hours = mean(mean_total_hours),
    mean_main_hours = mean(mean_main_hours),
    mean_other_hours = mean(mean_other_hours),
    
    multiple_job_pct = mean(multiple_job_pct),
    
    .groups = "drop"
  ) %>%
  mutate(
    # Calculate annual shares from the annual mean hours.
    # 使用年度平均工时计算年度工时占比。
    
    main_share_pct = 100 *
      mean_main_hours / mean_total_hours,
    
    other_share_pct = 100 *
      mean_other_hours / mean_total_hours,
    
    share_sum_pct = main_share_pct + other_share_pct
  ) %>%
  arrange(age_group, YEAR)

write_csv(
  annual_age_hours,
  file.path(processed_dir, "annual_age_hours.csv")
)


# ------------------------------------------------------------
# 17. Compare 2000 and 2024 / 比较 2000 年与 2024 年
# ------------------------------------------------------------

# Calculate changes in hours and percentage-point changes in shares.
# 计算工时变化量以及工时占比的百分点变化。

endpoint_changes <- annual_age_hours %>%
  filter(YEAR %in% c(2000, 2024)) %>%
  select(
    YEAR,
    age_group,
    mean_total_hours,
    mean_main_hours,
    mean_other_hours,
    main_share_pct,
    other_share_pct
  ) %>%
  pivot_wider(
    names_from = YEAR,
    values_from = c(
      mean_total_hours,
      mean_main_hours,
      mean_other_hours,
      main_share_pct,
      other_share_pct
    ),
    names_glue = "{.value}_{YEAR}"
  ) %>%
  mutate(
    total_hours_change =
      mean_total_hours_2024 - mean_total_hours_2000,
    
    main_hours_change =
      mean_main_hours_2024 - mean_main_hours_2000,
    
    other_hours_change =
      mean_other_hours_2024 - mean_other_hours_2000,
    
    total_hours_change_pct = 100 *
      total_hours_change / mean_total_hours_2000,
    
    main_share_change_pp =
      main_share_pct_2024 - main_share_pct_2000,
    
    other_share_change_pp =
      other_share_pct_2024 - other_share_pct_2000
  )

write_csv(
  endpoint_changes,
  file.path(processed_dir, "age_group_changes_2000_2024.csv")
)


# ------------------------------------------------------------
# 18. Display results / 显示结果
# ------------------------------------------------------------

cat("\n--- Sample types ---\n")
print(asec_audit, n = Inf)

cat("\n--- Sample flow ---\n")
print(sample_flow, n = Inf)

cat("\n--- Cleaning summary ---\n")
print(
  cleaning_audit %>%
    summarise(
      target_sample_rows = sum(target_sample_rows),
      retained_sample_rows = sum(retained_sample_rows),
      excluded_sample_rows = sum(excluded_sample_rows),
      single_job_conflict_n = sum(single_job_conflict_n),
      minimum_retained_weight_pct = min(retained_weight_pct)
    ),
  width = Inf
)

cat("\n--- Hours consistency summary ---\n")
print(
  consistency_audit %>%
    summarise(
      inconsistent_hours_n = sum(inconsistent_hours_n),
      total_over_168_n = sum(total_over_168_n),
      main_topcoded_n = sum(main_topcoded_n),
      other_topcoded_n = sum(other_topcoded_n)
    ),
  width = Inf
)

cat("\n--- Output dimensions ---\n")
cat("Monthly rows: ", nrow(monthly_age_hours), "\n", sep = "")
cat("Annual rows: ", nrow(annual_age_hours), "\n", sep = "")

cat("\n--- Annual estimates for 2000 and 2024 ---\n")
print(
  annual_age_hours %>%
    filter(YEAR %in% c(2000, 2024)),
  n = Inf,
  width = Inf
)

cat("\n--- Changes between 2000 and 2024 ---\n")
print(endpoint_changes, n = Inf, width = Inf)

cat(
  "\nStage 2 completed. Outputs saved to: ",
  processed_dir,
  "\n",
  sep = ""
)


# ------------------------------------------------------------
# 19. Check sensitivity to unusual hours / 检查异常工时的影响
# ------------------------------------------------------------

# Count overlapping conditions without double-counting observations.
# 统计异常条件的重叠情况，避免重复计算被排除的记录。

sensitivity_exclusions <- workers %>%
  summarise(
    baseline_sample_rows = n(),
    
    over_168_n = sum(total_hours > 168),
    
    inconsistent_hours_n = sum(
      abs(hours_gap) > 1e-8
    ),
    
    excluded_sample_rows = sum(
      total_hours > 168 | abs(hours_gap) > 1e-8
    ),
    
    excluded_record_pct = 100 *
      mean(total_hours > 168 | abs(hours_gap) > 1e-8)
  )

write_csv(
  sensitivity_exclusions,
  file.path(processed_dir, "sensitivity_exclusions.csv")
)

# Recalculate monthly estimates after excluding flagged records.
# 排除被标记的记录后，重新计算月度估计值。

sensitivity_monthly <- workers %>%
  select(
    YEAR, MONTH, age_group, WTFINL,
    total_hours, main_hours, other_hours, hours_gap
  ) %>%
  filter(
    total_hours <= 168,
    abs(hours_gap) <= 1e-8
  ) %>%
  group_by(YEAR, MONTH, age_group) %>%
  summarise(
    mean_total_hours = weighted.mean(
      total_hours, WTFINL
    ),
    
    mean_main_hours = weighted.mean(
      main_hours, WTFINL
    ),
    
    mean_other_hours = weighted.mean(
      other_hours, WTFINL
    ),
    
    .groups = "drop"
  )

# Confirm that no month-by-age-group cell was lost.
# 确认没有任何月份与年龄组组合因筛选而消失。

lost_cells <- monthly_age_hours %>%
  select(YEAR, MONTH, age_group) %>%
  anti_join(
    sensitivity_monthly,
    by = c("YEAR", "MONTH", "age_group")
  )

if (nrow(lost_cells) > 0) {
  print(lost_cells, n = Inf)
  
  stop(
    "Some month-by-age-group cells were lost in the sensitivity analysis.",
    call. = FALSE
  )
}

# Apply the same annual aggregation method as the baseline.
# 使用与基准结果相同的方法汇总年度统计量。

sensitivity_annual <- sensitivity_monthly %>%
  group_by(YEAR, age_group) %>%
  summarise(
    mean_total_hours = mean(mean_total_hours),
    mean_main_hours = mean(mean_main_hours),
    mean_other_hours = mean(mean_other_hours),
    .groups = "drop"
  ) %>%
  mutate(
    main_share_pct = 100 *
      mean_main_hours / mean_total_hours,
    
    other_share_pct = 100 *
      mean_other_hours / mean_total_hours
  ) %>%
  arrange(age_group, YEAR)

write_csv(
  sensitivity_annual,
  file.path(processed_dir, "annual_age_hours_sensitivity.csv")
)

# Compare all five figure metrics across the two specifications.
# 比较两种处理方式下五张图所使用的全部指标。

figure_metrics <- c(
  "mean_total_hours",
  "mean_main_hours",
  "mean_other_hours",
  "main_share_pct",
  "other_share_pct"
)

sensitivity_comparison <- annual_age_hours %>%
  select(YEAR, age_group, all_of(figure_metrics)) %>%
  pivot_longer(
    cols = all_of(figure_metrics),
    names_to = "metric",
    values_to = "baseline_estimate"
  ) %>%
  left_join(
    sensitivity_annual %>%
      pivot_longer(
        cols = all_of(figure_metrics),
        names_to = "metric",
        values_to = "restricted_estimate"
      ),
    by = c("YEAR", "age_group", "metric")
  ) %>%
  mutate(
    difference = restricted_estimate - baseline_estimate,
    absolute_difference = abs(difference)
  )

write_csv(
  sensitivity_comparison,
  file.path(processed_dir, "sensitivity_comparison.csv")
)

# Report the largest absolute difference across all years and age groups.
# 汇报所有年份与年龄组中最大的绝对差异。

sensitivity_summary <- sensitivity_comparison %>%
  group_by(metric) %>%
  summarise(
    max_absolute_difference = max(absolute_difference),
    .groups = "drop"
  ) %>%
  mutate(
    unit = if_else(
      metric %in% c("main_share_pct", "other_share_pct"),
      "percentage points",
      "hours per week"
    )
  )

write_csv(
  sensitivity_summary,
  file.path(processed_dir, "sensitivity_summary.csv")
)

cat("\n--- Sensitivity exclusions ---\n")
print(sensitivity_exclusions, width = Inf)

cat("\n--- Maximum sensitivity differences ---\n")
print(sensitivity_summary, n = Inf, width = Inf)

cat("\n--- Corrected monthly sample-size statistics ---\n")
print(
  annual_age_hours %>%
    filter(YEAR %in% c(2000, 2024)) %>%
    select(
      YEAR,
      age_group,
      sample_rows,
      minimum_monthly_sample_rows,
      maximum_monthly_sample_rows,
      average_monthly_sample_rows
    ),
  n = Inf,
  width = Inf
)