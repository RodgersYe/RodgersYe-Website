# Blog Post 5: Is Living Alone Easier Where More People Do It?

## Overview

This project examines the geography of living alone and rental affordability across the 50 U.S. states in 2024. It uses American Community Survey (ACS) microdata obtained through IPUMS USA to compare the prevalence of living alone with severe rent burden among adult one-person renter households.

The analysis distinguishes two questions: **where is living alone common, and where does renting alone absorb a large share of income?** These questions involve different populations and weights. Their comparison provides geographic context without treating living-alone prevalence as a direct measure of rental affordability.

This README documents the data sources, sample definitions, four R scripts, file roles, and reproduction steps. The final analytical pipeline produces **one processed RDS, two CSV reports, and three PNG figures**. Washington, D.C., is retained separately in the data and reports but excluded from the main comparison and figures.

## Research Background

Living alone means paying housing costs without sharing them with another household member. For someone comparing places to live, calculating rent as a share of income is straightforward; understanding whether that burden is common requires context. A high ratio can reflect expensive housing, limited income, or both.

The blog starts with a contrast between North Dakota and Florida. Living alone is more common in North Dakota, while severe rent burden among positive-income adult solo renters is much more common in Florida. Two maps and a state comparison chart explore that mismatch. Income and age-group summaries help explain why a smaller rent bill does not necessarily imply a lighter income-based burden.

This is a descriptive GIS project. It does not estimate the causal effect of living alone, explain every source of state differences, or recommend a particular relocation destination.

## Research Question

**Is renting alone more affordable in states where living alone is more common?**

Supporting comparisons examine:

- The share of positive-income adult solo renters whose annualized gross rent exceeds 30% or 50% of income.
- Differences in severe burden across states, including uncertainty around the estimates.
- The relationship between state living-alone prevalence and severe rent burden.
- Differences in rent, income, and burden between renters aged 18–64 and those aged 65 or older.

## Data Sources

### IPUMS USA: 2024 ACS One-Year Microdata

**Underlying provider:** U.S. Census Bureau, American Community Survey.

**Harmonization and access:** [IPUMS USA](https://usa.ipums.org/usa/), using its API through the R package `ipumsr`.

**Sample:** `us2024a`, the 2024 ACS one-year sample. The downloaded records have `YEAR = 2024` and `SAMPLE = 202401`. This project does not use the 2020–2024 ACS five-year sample, IPUMS CPS, or multiple survey years. See the [IPUMS sample identifiers](https://usa.ipums.org/usa-action/samples/sample_ids).

**Access method:** Script 01 requests rectangular person records in fixed-width format, with data-quality flags and 80 household replicate weights. It retains the complete sample rather than applying the research filters on the server. Complete household membership is needed for validation, and all residents are needed for the population-share map.

**Original acquisition:** The project download log records completion on October 8, 2026, at 01:00:50 UTC. The original account-specific task was `usa:1`. A reproducer receives their own task number and must not copy that identifier into a different account.

**Original files:**

- `data/raw/ipums_2024/usa_00001.xml`: official DDI codebook describing variables, coding, record layout, and implied decimals.
- `data/raw/ipums_2024/usa_00001.dat.gz`: official compressed microdata file.

The scripts identify a matching `usa_*.xml` and `usa_*.dat.gz` pair, so a reproducer's extract does not need to be numbered `00001`. Keep exactly one intended pair in the raw-data directory. Preserve both files unchanged and read the compressed data with the DDI; manual decompression or conversion to CSV is unnecessary.

### Variables Requested

Script 01 contains the complete extract specification. The variables serve the following roles:

| Role | Variables |
|---|---|
| Survey and record identifiers | `YEAR`, `SAMPLE`, `SERIAL`, `PERNUM` |
| Geography and household composition | `STATEFIP`, `GQ`, `NUMPREC`, `AGE` |
| Tenure | `OWNERSHP`; the extract also supplies detailed `OWNERSHPD` |
| Main income and rent measures | `INCTOT`, `HHINCOME`, `RENT`, `RENTGRS` |
| Main survey weights | `HHWT`, `PERWT` |
| Household uncertainty estimates | `REPWT`, which supplies `REPWT1`–`REPWT80` |
| Monetary adjustment field retained for checking | `ADJUST` |
| Additional income components retained in the raw extract | `INCWAGE`, `INCBUS00`, `INCINVST`, `INCSS`, `INCRETIR`, `INCWELFR`, `INCSUPP`, `INCOTHER` |
| Additional utility components retained in the raw extract | `COSTELEC`, `COSTGAS`, `COSTFUEL`, `COSTWATR` |

The raw extract includes the requested quality flags. Script 02 retains the fields needed downstream and available variables beginning with `Q`; it does not copy every raw variable into the processed dataset.

### State Map Geometry

**Provider:** U.S. Census Bureau.

**Source file:** [2024 state cartographic boundaries, 1:20,000,000](https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_us_state_20m.zip).

**Local file:** `data/raw/geography/cb_2024_us_state_20m.zip`.

Script 04 downloads this ZIP only when it is missing. It reads the shapefile through GDAL's ZIP interface without extracting permanent companion files. This file supplies state outlines and identifiers, not income, rent, or population observations. A separate geometry retrieval timestamp is not written by the final script.

The maps join statistics to geometry using state FIPS codes. The contiguous-state panel uses EPSG:5070; Alaska uses EPSG:3338 and Hawaii EPSG:4326 in separate panels. The panels use different geographic scales, and the Hawaii panel displays the main islands. The two maps also use different numerical color scales because they show different measures.

## Data and Reproducibility Notes

- Paths resolve from the website repository root, with this post at `blog/posts/post5/`. Run the scripts from the root RStudio Project or a repository-root R session.
- Local raw microdata and the household-level RDS are excluded by the scripts' `.gitignore` rules. A clone should provide code, aggregate reports, figures, and article assets; full reproduction requires obtaining the microdata through the reproducer's own IPUMS account. Confirm which aggregate files are actually committed.
- `.Renviron` stores a private API key. `extract_id.txt` stores resumable API task state. Neither is a statistical output.
- The API key is unnecessary when a complete local raw pair is already available and stage `auto` reuses it. A fresh acquisition requires IPUMS USA access and an API key.
- The final pipeline does not generate `session_info.txt`, `selected_sample_metadata.csv`, `download_receipt.csv`, an extract-definition JSON, separate diagnostic datasets, PDFs, or a figure manifest. Older versions may have left such files locally; the current pipeline does not depend on them.
- Metadata and source-file checksums are embedded in the RDS, while substantive checks are consolidated in `data_validation_report.csv`. Statistical estimates are consolidated in `statistical_summary.csv`; both CSVs contain structured values rather than narrative interpretation.
- Fresh downloads may reflect source revisions. Matching the sample and variable specification supports reproducibility but does not guarantee byte-identical files or permanently unchanged estimates.
- The original acquisition log reports `ipumsr` 0.10.0. A complete software lockfile is not supplied, so exact R, Quarto, and dependency versions are not pinned.

## Sample Definitions and Measures

### Adult One-Person Renter Households

Script 02 retains records satisfying all of the following:

| Condition | Implementation |
|---|---|
| Household residents | `GQ %in% c(1, 2)` |
| Exactly one household member | `NUMPREC == 1` |
| One reference record per household | `PERNUM == 1` |
| Adult | Valid `AGE >= 18`; exclude age code `999` |
| Geography | 50 states or D.C.; assign D.C. a separate study scope |
| Rented for cash rent | `OWNERSHPD == 22` |
| Positive monthly gross rent | Finite `RENTGRS > 0` |
| Positive household weight | Finite `HHWT > 0` |

There are **no restrictions by sex, marital status, employment, bedroom count, or building type**. Living alone is not defined as never having married. The results cover eligible rental housing generally, not only one-bedroom apartments.

The RDS contains both `main_50_states` and `DC_separate` records. D.C. is not exported as a second processed dataset.

### Income, Rent, and Affordability

Annual income uses `INCTOT`, the person's total pretax income for the preceding 12 months. `HHINCOME` is retained for consistency checking, but does not replace `INCTOT` in the burden calculation. For a one-person household, the personal and household income measures can be compared directly.

`annual_income` retains valid zero and negative values for descriptive summaries. Missing values, `INCTOT = 9999999` (not in universe), and `9999998` (unknown) are treated as unavailable. Code `1`, which can represent one dollar or break-even income, is flagged as ambiguous and assigned `NA` in `annual_income`. Only valid positive income qualifies a record for rent-to-income ratios.

`RENTGRS` is monthly gross rent, including utilities and fuel. The transformations are:

$$
\text{Annualized gross rent}_i = 12\times\text{RENTGRS}_i,
$$

$$
\text{Rent-to-income ratio}_i
=\frac{\text{Annualized gross rent}_i}{\text{Annual income}_i},
\qquad \text{Annual income}_i>0.
$$

Burden indicators use strict thresholds: ratio **greater than 0.30** and **greater than 0.50**. A ratio exactly equal to a threshold is not counted above it. Zero- and negative-income households remain in the RDS and relevant descriptive summaries, but are excluded from these ratios and burden rates.

The DDI reader applies implied decimals. The scripts do not additionally multiply income, rent, or weights by `ADJUST`. Monetary estimates retain the project's unadjusted nominal-dollar specification.

The median household ratio is calculated from individual households' ratios. It is not the median rent divided by the median income. Rent summaries use all cleaned households, income summaries use valid income, and ratio summaries use valid positive income; consult each CSV row's denominator fields when comparing them.

### Living-Alone Population Share

Figure 3 uses the complete raw person file, not the renter RDS. For state \(s\):

$$
\text{Living-alone share}_s
=\frac{\sum_{i\in s}\text{PERWT}_i
\,\mathbf{1}(GQ_i\in\{1,2\},\ NUMPREC_i=1,\ PERNUM_i=1)}
{\sum_{i\in s}\text{PERWT}_i}.
$$

The numerator includes people of all ages and housing tenures who live alone in households. The denominator includes **all state residents, including residents of group quarters**. A group-quarters record is not classified as living alone merely because its record structure suggests one person.

The summary also retains an unweighted `living_alone_sample_record_share` for transparency. This is a share of sample records and is not the population estimate plotted in Figure 3. Population context is appended to the existing statistical CSV; no second processed population dataset is created.

### Weighting and Uncertainty

Household estimates use `HHWT`. The pooled 50-state burden rate is calculated across eligible weighted households, not as an equally weighted average of state percentages. Population shares use `PERWT`.

For burden proportions, script 03 recomputes estimates using the 80 household replicate weights and applies ACS successive difference replication:

$$
SE(\hat\theta)=\sqrt{\frac{4}{80}\sum_{r=1}^{80}
(\hat\theta_r-\hat\theta)^2}.
$$

The script uses normal 95% intervals, `estimate ± qnorm(0.975) * standard_error`. Signed replicate weights are retained rather than arbitrarily set to zero. See the [IPUMS replicate-weight documentation](https://usa.ipums.org/usa/repwt.shtml).

Medians, quartiles, means, and descriptive standard deviations are point estimates. Quantiles use the weighted empirical cumulative distribution; descriptive standard deviations use the weighted squared deviations divided by the sum of weights. They are not standard errors. The extract does not request person replicate weights, so Figure 3's population shares have no confidence intervals. `ci_status = "not_requested"` records that decision rather than a failed validation.

## Analytical Workflow

| Stage | Main inputs | Main outputs |
|---|---|---|
| 01 — Acquire | Extract specification, local raw files or personal IPUMS credentials | Official XML/data pair; task ID when submitting a request |
| 02 — Clean | Official XML/data pair | One household-level RDS |
| 03 — Validate and analyze | Raw XML/data pair and the RDS | Consolidated validation CSV and statistical summary CSV |
| 04 — Plot | Both CSVs; Census state boundaries | Three analytical PNGs |
| Render article | Article source, three PNGs, cover, website configuration | Rendered blog page |

### Step 1 — Data Acquisition

**Script:** `code/01_get_raw_data.R`.

The default `auto` stage reuses a complete local raw pair before checking credentials. Otherwise, it resumes a saved task or submits the specified extract, saves its ID immediately, waits for completion, and downloads the official files.

| Stage option | Behavior |
|---|---|
| `auto` | Reuse existing files; otherwise resume a saved task or submit, wait, and download. |
| `check` | Retrieve sample information and print the specification; submit no extract and download no microdata. Requires API access. |
| `submit` | Reuse an existing raw pair if present; otherwise submit once and save the ID without downloading. Refuses another submission when a task ID is already saved. |
| `download` | Reuse an existing raw pair if present; otherwise wait for and download the locally saved task. Does not submit a new task. |

**Outputs:** The official `.xml` and `.dat.gz` pair, plus `extract_id.txt` when a task is submitted. This task-state file is useful for recovering from an interrupted wait and is not a validation report.

### Step 2 — Cleaning

**Script:** `code/02_clean_data.R`.

The script reads the raw file in chunks, applies the adult one-person renter filters, classifies income codes, creates annualized rent and ratio-eligibility fields, assigns state and age labels, and stores source lineage inside the dataset. It performs input/schema checks needed to proceed; comprehensive validation is centralized in script 03.

**Output:** `data/processed/single_person_renters_clean.rds`.

### Step 3 — Consolidated Validation and Analysis

**Script:** `code/03_analyze_data.R`.

The script checks processed fields, identifiers, source checksums, DDI parsing, filtering, income coding, and weight values. It rereads the full raw file to check complete household membership across chunk boundaries and to calculate population context. The raw data therefore remain necessary even when the RDS already exists.

It estimates state, pooled 50-state, and separate D.C. household distributions for all adults, ages 18–64, and ages 65+. Income, annualized rent, and eligible ratios receive medians, quartiles, means, and descriptive standard deviations. The two burden proportions receive replicate-weight standard errors and confidence intervals. All-age population and sample-record shares are appended to the same statistical summary.

**Outputs:** Exactly two CSV reports in `data/processed/`. Failed validation writes the consolidated report and stops before refreshing statistical output. A completed analysis is marked by `analysis_completed = PASS` in the report; stale statistical output must not be treated as a successful new run.

### Step 4 — Figure Generation

**Script:** `code/04_make_figures.R`.

Script 04 requires both consolidated CSVs, checks their shared run ID and processed-data checksum, and requires a completed analysis without `FAIL` entries. If the RDS is present, it also checks that it has not changed since analysis. These are lightweight input-consistency checks, not a second full raw-data validation.

The script joins estimates to Census boundaries and exports three 300-dpi PNGs. After all three exports succeed, it removes the five obsolete filenames from the earlier figure layout. No PDFs, figure manifest, or separate figure-check files are generated.

### Step 5 — Blog Rendering

The article uses the saved analytical images and a separately created cover. Scripts 01–04 generate analytical assets; they do not write the blog narrative or regenerate the cover. Run the R pipeline before rendering a page that references updated figures.

Rendering examples below use `BlogPost05.qmd` and the layout uses `BlogPost05Cover.png`. These are article naming conventions; substitute the actual filenames and match the QMD's image references if your saved article or cover uses another name. The final QMD was not supplied with the analytical scripts, so its executable chunks and exact asset references require a local check.

## Project Structure and File Guide

All paths below are relative to `blog/posts/post5/`. This is the intended final layout; local microdata are regenerated by each reproducer, not assumed to be included in a clone.

| Path | Role |
|---|---|
| `README.md` | Research, data, methods, file guide, and reproduction instructions. |
| `BlogPost05.qmd` | Article source; filename used in the rendering example. |
| `BlogPost05Cover.png` | Separately created square cover; filename must match the article's reference. |
| `code/01_get_raw_data.R` | Reuses, resumes, or acquires the official raw extract. |
| `code/02_clean_data.R` | Filters and transforms raw records into one RDS. |
| `code/03_analyze_data.R` | Validates data and creates both CSV reports. |
| `code/04_make_figures.R` | Creates the final three analytical PNGs. |
| `data/raw/ipums_2024/usa_*.xml` | Official DDI for the matching data file; required for reading and validation. |
| `data/raw/ipums_2024/usa_*.dat.gz` | Unmodified, compressed person-level extract; local only. |
| `data/raw/ipums_2024/extract_id.txt` | Local, account-specific API task ID for resuming acquisition. |
| `data/raw/geography/cb_2024_us_state_20m.zip` | Cached state boundaries downloaded by script 04. |
| `data/processed/single_person_renters_clean.rds` | Household-level data, derived variables, weights, and embedded lineage; local only. |
| `data/processed/data_validation_report.csv` | Consolidated validation results and descriptive checks. |
| `data/processed/statistical_summary.csv` | Aggregate distributions and estimates used for figures and writing. |
| `figures/fig01_severe_burden_intervals.png` | State severe-burden estimates, 95% intervals, and pooled benchmark. |
| `figures/fig02_severe_rent_burden_map.png` | Geographic distribution of severe burden among eligible solo renters. |
| `figures/fig03_living_alone_population_share_map.png` | Geographic distribution of living alone among all residents. |

### Reading the Two CSV Reports

`data_validation_report.csv` contains `section`, `check`, `observed`, `expected`, `n_checked`, `n_failures`, `weighted_n`, `status`, and `severity`, with geography and variable fields where relevant. `PASS` means the specified check passed; `INFO` supplies counts or profiles; `WARN` identifies a concern; `FAIL` blocks completion. An informational row is not an additional hypothesis test.

`statistical_summary.csv` is a long-format table. Select rows using `geography`, `STATEFIP`, `age_scope`, and `metric`. Main state renter results use `geography = "state"` and `age_scope = "all_adults"`; population results use `age_scope = "all_ages"`. Pooled rows use `geography = "pooled_50_states"`; D.C. uses `"DC_separate"`.

Useful metric names include:

| Metric | Meaning |
|---|---|
| `burden_share_over30_positive` | Eligible household share with ratio strictly above 0.30. |
| `burden_share_over50_positive` | Eligible household share with ratio strictly above 0.50. |
| `median_annual_income_all_valid` | Weighted median income, including valid zero/negative income. |
| `median_annualized_gross_rent_all` | Weighted median annualized rent across cleaned households. |
| `median_rent_income_ratio_positive` | Weighted median of eligible household ratios. |
| `living_alone_population_share` | Person-weighted share plotted in Figure 3. |
| `living_alone_sample_record_share` | Unweighted sample-record share, not plotted. |

Use `unit`, `denominator`, `observation_unit`, `weight_variable`, `n_denominator`, and `weighted_denominator` to interpret a row. Proportions are stored as fractions: `0.331` means approximately 33.1%. Household-domain fields can be `NA` on person-level population rows by design. Both CSVs identify the analysis run; the summary also records the processed RDS checksum.

## How to Reproduce the Analysis

### 1. Clone or Open the Website Repository

```bash
git clone https://github.com/RodgersYe/RodgersYe-Website.git
cd RodgersYe-Website
```

Open the root RStudio Project, or start R from this repository root. Keep all four scripts at `blog/posts/post5/code/`. Their `here::i_am()` declarations refer to that path; do not start from a different project or move the scripts without updating their path declarations.

### 2. Install R Packages and Quarto

In the R console:

```r
install.packages(c(
  "here", "ipumsr", "data.table", "tidyselect",
  "sf", "ggplot2", "scales", "patchwork", "ggrepel"
))
```

`ipumsr` handles acquisition and DDI-based reading; `data.table` handles tabular processing; `tidyselect` selects fields during chunked reading. `sf`, `ggplot2`, `scales`, `patchwork`, and `ggrepel` support mapping and plotting. The spatial dependencies required by `sf` must be available on the local system. Install Quarto separately to render the blog.

### 3. Configure Access When Raw Data Are Missing

Register for [IPUMS USA](https://usa.ipums.org/usa/) and obtain a personal API key through the [IPUMS Developer Portal](https://developer.ipums.org/). In a private repository-root `.Renviron`, add:

```text
IPUMS_API_KEY=YOUR_PERSONAL_KEY
```

Restart R, or load the file without printing the key:

```r
readRenviron(here::here(".Renviron"))
nzchar(trimws(Sys.getenv("IPUMS_API_KEY")))
```

The check should return `TRUE`. Do not place the real key in an R script, README, or commit. The scripts append local-data and credential exclusions to `.gitignore`; ignore rules do not remove files that were already tracked.

If an authorized matching XML/data pair is already present, skip credential setup and let `auto` reuse it. The map boundary ZIP is retrieved independently and needs internet access only if absent.

### 4. Run the Four Scripts in Order

From the repository-root R session:

```r
options(blog5.ipums_stage = "auto")

scripts <- c(
  "01_get_raw_data.R",
  "02_clean_data.R",
  "03_analyze_data.R",
  "04_make_figures.R"
)

for (script in scripts) {
  source(here::here("blog", "posts", "post5", "code", script))
}
```

This submits and downloads only when needed. When the existing raw pair is complete, script 01 reports that no API request was made. Sourcing each script also calls its main function; do not call that function again immediately unless you intend to rerun the stage.

To inspect a fresh extract specification before submission, run script 01 alone with `options(blog5.ipums_stage = "check")`. Then switch to `"auto"`, or run `"submit"` followed by `"download"`, using the same source command. These stage options belong in the console, not inside a script that sources itself.

If waiting times out, rerun stage `download` or `auto` with the saved task ID. Do not delete the ID and automatically submit a duplicate. If a remote extract is no longer available, inspect the task in your own account and deliberately arrange a replacement. Extract task numbers and download availability are not permanent dataset identifiers.

The raw file contains more than 3.4 million person records. Chunked reading reduces input overhead, but script 03 retains household-membership information for cross-chunk checks and can require substantial memory and several minutes. Progress messages are expected.

### 5. Inspect the Consolidated Results

In the R console, without creating additional files:

```r
validation <- data.table::fread(here::here(
  "blog", "posts", "post5", "data", "processed",
  "data_validation_report.csv"
))

validation[, .N, by = status]
validation[status %in% c("FAIL", "WARN")]
validation[section == "pipeline" & check == "analysis_completed"]
```

The supplied completed analysis has **170 `PASS` rows, 3,037 `INFO` rows, and no `FAIL` or `WARN` rows**. Validation establishes the checked properties, not the absence of all survey or measurement error. Do not bypass a failed check to obtain figures.

Expected benchmarks for the supplied extract are:

| Benchmark | Value |
|---|---:|
| Raw person records, including D.C. | 3,422,888 |
| Cleaned adult one-person renter households, 50 states | 135,366 |
| Separate D.C. households in the same RDS | 841 |
| Positive-income ratio-eligible households, 50 states | 131,120 |
| Weighted ratio-eligible coverage of cleaned 50-state households | 96.6% |
| Pooled share above 30% of income | 60.6% |
| Pooled share above 50% of income | 33.1% |
| Pooled severe-burden 95% interval | 32.8%–33.5% |

The supplied summary has 2,756 rows; the validation report has 3,207. These counts describe the current schema and sample, not independent substantive targets for future data revisions. Run IDs and an RDS checksum can change when data are regenerated because the RDS includes a cleaning timestamp. Compare estimates and checks rather than requiring identical regenerated hashes.

### 6. Regenerate Figures or Render the Blog

If both aggregate CSVs are available from a completed matching run, script 04 can regenerate all three analytical figures without raw microdata or the RDS. It checks the RDS checksum only if that file is present. Run:

```r
source(here::here(
  "blog", "posts", "post5", "code", "04_make_figures.R"
))
```

If the geometry ZIP is already cached, this figure-only route needs no download. Full recalculation and validation still require the raw pair and scripts 02–03; the aggregate CSVs alone cannot reconstruct individual household data.

After confirming the three PNGs, cover filename, and article image references, render from a repository-root terminal:

```bash
quarto render blog/posts/post5/BlogPost05.qmd
```

This command renders the article within the website's Quarto configuration. It does not itself invoke the four external scripts; any additional execution depends on the actual QMD contents. Analytical figures and the cover are separate assets.

## Outputs

The final output contract is:

- **One RDS:** cleaned household-level observations with embedded lineage, stored locally.
- **Two CSVs:** consolidated validation and aggregate statistical distributions, with interpretation reserved for the article.
- **Three PNGs:** severe-burden intervals, severe-burden map, and living-alone population-share map.

The official IPUMS pair, resumable task ID, and cached Census ZIP are inputs or acquisition state rather than additional analysis reports. The blog source, rendered page, and cover are presentation assets outside the four scripts' analytical output contract.

## Key Findings

These results provide numerical benchmarks for the blog, rather than causal conclusions:

- **The two geographic patterns do not coincide.** North Dakota's living-alone population share is 14.9%, against Florida's 11.0%; severe burden among eligible solo renters is 20.9% in North Dakota and 42.3% in Florida. California combines an 8.6% living-alone share with a 38.7% severe-burden rate.
- **Severe burden is widespread and uneven.** The pooled rate is 33.1%, while South Dakota's point estimate is 18.4% and Florida's is 42.3%. Figure 1 shows the uncertainty that a map of point estimates cannot display.
- **Lower rent does not guarantee a lower income-based burden.** Renters aged 65+ have median annualized rent of $12,000, compared with $16,200 among ages 18–64, but higher severe burden: 41.6% versus 29.8%. Their median incomes are $22,800 and $43,000, respectively.

The article also reports an approximately −0.49 Pearson correlation between the two state-level shares, giving each state equal weight. This is a descriptive calculation from the 50 matched state estimates; it is not a separately exported metric or a causal model in script 03. It can be reproduced from the existing summary without writing another file:

```r
summary_data <- data.table::fread(here::here(
  "blog", "posts", "post5", "data", "processed", "statistical_summary.csv"
))

burden <- summary_data[
  geography == "state" & age_scope == "all_adults" &
    metric == "burden_share_over50_positive",
  .(STATEFIP, severe_burden = estimate)
]
population <- summary_data[
  geography == "state" & age_scope == "all_ages" &
    metric == "living_alone_population_share",
  .(STATEFIP, living_alone = estimate)
]
comparison <- merge(burden, population, by = "STATEFIP")
stopifnot(nrow(comparison) == 50L)
cor(comparison$living_alone, comparison$severe_burden, method = "pearson")
```

**Main takeaway:** A state where living alone is common is not necessarily a state where renting alone places less pressure on income. Affordability depends on rent relative to available income, with important differences across places and age groups.

## Limitations

- This is a one-year, state-level description. It does not identify causation, changes over time, or conditions in a particular city, neighborhood, or apartment.
- The population map includes homeowners and renters of all ages; the burden figures describe positive-income adult one-person renter households. Their denominators and weights differ. State correlations cannot be interpreted as individual-level relationships.
- Rent is an annualization of current monthly gross rent, while income covers the preceding 12 months. The ratio does not measure actual calendar-year rent payments, after-tax disposable income, wealth, or available savings.
- Zero, negative, unavailable, and ambiguous income do not enter burden ratios. Severe-burden rates therefore do not capture every financially vulnerable solo renter.
- Estimates describe existing tenants rather than currently advertised units. The dataset does not separately identify students or restrict housing to one-bedroom apartments.
- Sampling uncertainty matters, particularly when comparing nearby state estimates. Figure 1's ordering is descriptive rather than a complete set of pairwise significance tests. Figure 3 and the distribution medians are point estimates without estimated confidence intervals.
- Harmonization, allocation, top/bottom coding, and survey measurement can affect estimates. Recorded quality-code distributions and successful structural checks do not eliminate these concerns.
- Package versions and source releases are not fully frozen. A fresh extraction or software update may change results or presentation. The reproduction instructions describe the final four-script, three-figure version, not earlier scripts that produced additional files.

## Data Attribution and Usage

**IPUMS USA citation:**

Steven Ruggles, Sarah Flood, Matthew Sobek, Daniel Backman, Grace Cooper, Julia A. Rivera Drew, Stephanie Richards, Renae Rodgers, Jonathan Schroeder, and Kari C.W. Williams. *IPUMS USA: Version 16.0* [dataset]. Minneapolis, MN: IPUMS, 2025. [https://doi.org/10.18128/D010.V16.0](https://doi.org/10.18128/D010.V16.0).

**Underlying survey and boundaries:** U.S. Census Bureau, 2024 American Community Survey one-year microdata and 2024 state cartographic boundary files.

**Suggested figure credit:** Data: IPUMS USA, 2024 ACS one-year; underlying data: U.S. Census Bureau. Boundaries: U.S. Census Bureau, 2024. Calculations and visualizations: author's analysis.

Consult the [IPUMS citation guidance](https://usa.ipums.org/usa/cite.shtml) and [IPUMS USA terms of use](https://usa.ipums.org/usa/terms.shtml). This project's public reproduction route uses code and aggregate outputs while each reproducer acquires microdata through their own account. Do not treat a code license as permission to redistribute IPUMS microdata; the terms address sample-data redistribution and its exceptions separately.

The ratios, summaries, maps, and interpretation are the author's calculations, not official IPUMS or Census Bureau affordability estimates. The decorative cover is an illustration and does not encode statistical values.

**Repository:** [RodgersYe / RodgersYe-Website](https://github.com/RodgersYe/RodgersYe-Website).
