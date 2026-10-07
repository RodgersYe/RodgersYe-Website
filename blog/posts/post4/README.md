# Blog Post 4: The Price Tag Behind America's Income Rankings

## Overview

This project compares nominal and regional-price-adjusted per capita personal income (PCPI) across the 50 U.S. states in 2024. It combines U.S. Bureau of Economic Analysis (BEA) income data with all-items regional price parities (RPPs), calculates two income rankings, and visualizes changes in states' positions.

This README documents the data sources, script dependencies, file roles, and steps needed to reproduce the analysis and render `BlogPost04.qmd`. The District of Columbia and the U.S. aggregate are excluded from the analysis.

## Research Background

The blog begins with a practical question arising from a job search: how should income figures be compared when local prices differ? Two identical salary offers do not necessarily imply identical purchasing power, but state averages also cannot determine which job or location is best for an individual.

The project examines the broader state-level comparison using a consistent income measure and price index for the same year. BEA's PCPI includes income beyond wages, while all-items RPP provides a common basis for comparing state price levels. The analysis asks how much accounting for those prices changes the ordering suggested by nominal income alone.

## Research Question

**Do the states with the highest incomes stay at the top once local prices are taken into account?**

Supporting comparisons identify which states move up or down, how large those movements are, and how much the nominal and adjusted top-ten groups overlap.

## Data Sources

### Archived Nominal Per Capita Personal Income

**Provider:** U.S. Bureau of Economic Analysis (BEA).

**Source:** [Regional Economic Accounts data archive](https://apps.bea.gov/histdata/RegionalAccounts.html); [Personal Income by State](https://www.bea.gov/data/income-saving/personal-income-by-state).

**Data coverage:** The archive member covers 1929–2024. This analysis selects 2024, SAINC1 line 3, PCPI in dollars, for the 50 states.

**Date accessed or downloaded:** Not confirmed in the supplied materials. **September 26, 2025 is the release date**, not a verified download date.

**Access method:** Historical ZIP obtained separately from the BEA archive; `01_get_raw_data.R` does not download it.

**Files used:** `data/raw/bea_state_annual_income_2025-09-26.zip`, containing `SAINC1__ALL_AREAS_1929_2024.csv`.

This fixed historical income vintage supplies the nominal PCPI values used in the published rankings. Script 02 reads the CSV directly inside the ZIP; extraction is unnecessary.

### API Nominal Per Capita Personal Income — Revision Audit

**Provider:** U.S. Bureau of Economic Analysis (BEA).

**Source:** [BEA Data API](https://apps.bea.gov/api/signup/); endpoint: `https://apps.bea.gov/api/data/`.

**Data coverage:** Regional dataset, SAINC1 line 3, year 2024, `GeoFips=STATE`, dollars. Script 02 retains the 50-state comparison.

**Date accessed or downloaded:** The exact timestamp has not been verified from the supplied materials. Script 01 records the retrieval time in `data/raw/bea_2024_metadata.rds` under `retrieved_at_utc`.

**Access method:** API request through `httr2`, using the reproducer's own BEA API UserID.

**Files used:** `data/raw/bea_nominal_pcpi_2024.csv`.

This later API income vintage is compared with the historical ZIP to audit revisions. It is required by script 02, but does not supply the nominal-income values for the main rankings. The revision count and largest absolute revision are printed to the console rather than saved as a separate dataset.

### API All-Items Regional Price Parities

**Provider:** U.S. Bureau of Economic Analysis (BEA).

**Source:** [Regional Price Parities](https://www.bea.gov/data/prices-inflation/regional-price-parities-state-and-metro-area); [BEA Data API](https://apps.bea.gov/api/signup/).

**Data coverage:** Regional dataset, SARPP line 1, year 2024, `GeoFips=STATE`, index. The analysis excludes D.C. and the U.S. aggregate and retains 50 states.

**Date accessed or downloaded:** Exact timestamp not verified; recorded by script 01 as `retrieved_at_utc` in `data/raw/bea_2024_metadata.rds`.

**Access method:** API request through `httr2`, using a personal BEA API UserID.

**Files used:** `data/raw/bea_all_items_rpp_2024.csv`.

All-items RPP supplies the price adjustment. An index of 100 represents the national average price level. The calculation uses this overall index rather than a separately constructed basket of rents or other selected expenses.

### API Official Real Per Capita Personal Income — Validation

**Provider:** U.S. Bureau of Economic Analysis (BEA).

**Source:** [Regional Price Parities and Real Personal Income](https://www.bea.gov/data/prices-inflation/regional-price-parities-state-and-metro-area); [BEA Data API](https://apps.bea.gov/api/signup/).

**Data coverage:** Regional dataset, SARPI line 2, year 2024, `GeoFips=STATE`, constant 2017 dollars. The analysis retains 50 states.

**Date accessed or downloaded:** Exact timestamp not verified; recorded by script 01 as `retrieved_at_utc` in `data/raw/bea_2024_metadata.rds`.

**Access method:** API request through `httr2`, using a personal BEA API UserID.

**Files used:** `data/raw/bea_official_real_pcpi_2024.csv`.

This series validates the adjusted ranking and the consistency of source vintages. It is not substituted for the project's own adjusted-PCPI calculation, which does not convert income to constant 2017 dollars.

### Map Geometry

Script 04 obtains 2024 state geometry and label locations through `usmap` and `usmapdata`, using `sf` for spatial operations. No separate shapefile or companion files are listed in `data/raw/`. The supplied materials do not record an independent geometry download date or package versions.

## Data and Reproducibility Notes

- The supplied folder screenshot shows the historical ZIP, three API CSVs, and metadata RDS in `data/raw/`. Confirm that these files are included in the cloned checkout; a local screenshot does not establish their Git tracking status.
- `data/raw/` preserves source data and acquisition metadata. Do not manually edit the source values. `data/processed/` contains cleaned or derived datasets generated by scripts 02 and 03.
- Reusing the saved ZIP and CSV snapshots requires no API key or API registration. A personal BEA API UserID is needed only to run script 01 and retrieve fresh API data.
- Script 01 overwrites all three API CSVs and the metadata RDS. Fresh downloads may contain revised 2024 values and may change results or fail script 03's vintage checks. Preserve the existing snapshots to reproduce the published comparison.
- Retain `bea_2024_metadata.rds` for provenance: it records the requested series, selected BEA metadata and notes, production timestamps when supplied, and retrieval time. Scripts 02–04 do not read it. Script 01 deliberately excludes the API key and full response from the saved metadata.
- All scripts resolve paths with `here::here()` relative to the website repository root and expect the post at `blog/posts/post4/`. Run them from the root RStudio Project or a repository-root shell.
- The current QMD references **five analytical PNGs**. Script 04 regenerates three of them. The two additional ranking PNGs must be retained to render the complete article; their generating code is not present in the supplied four scripts.
- BEA's reproduction policy permits reuse of website information unless otherwise stated. API use is also subject to its terms. See **Data Attribution and Usage** for source credits and the API notice.

## Analytical Workflow

The historical ZIP and saved API snapshots feed cleaning, analysis, and figure generation; Quarto then embeds the saved images in the article.

```text
Historical income ZIP + three API CSV snapshots
    → code/02_clean_data.R
    → data/processed/state_income_prices_2024.csv
    → code/03_analyze_data.R
    → state_income_analysis_2024.csv + rank_summary_2024.csv
    → code/04_make_figures.R
    → two maps + rank-change chart
    → BlogPost04.qmd, together with the retained ranking PNGs and cover
```

### Step 1 — Data Acquisition, When Needed

**Script:** `code/01_get_raw_data.R`.

The script reads `BEA_API_KEY` from the environment and requests three 2024 Regional API series: SAINC1 line 3, SARPP line 1, and SARPI line 2. It checks that each response contains usable data for the requested year and finishes all requests before writing files.

**Inputs:** Internet access and a personal BEA API UserID.

**Outputs:** The three `bea_*_2024.csv` files and `data/raw/bea_2024_metadata.rds`.

The historical ZIP must be supplied separately. Skip this script when the required saved CSVs are already available and the goal is to reproduce the published results.

### Step 2 — Cleaning and Merging

**Script:** `code/02_clean_data.R`.

**Inputs:** The historical income ZIP and all three API CSVs.

The script reads archived SAINC1 line 3 for 2024, removes trailing footnote markers from geographic names, converts values to numeric form, and checks units, geographic identifiers, positive values, and coverage. It excludes the U.S. aggregate and D.C., then merges archived income, RPP, and official real PCPI by geographic code, state name, and year.

The output must contain one complete row for each of the 50 states. The later API income series is used only for a console revision audit.

**Output:** `data/processed/state_income_prices_2024.csv`, containing `GeoFips`, `state`, `year`, `nominal_pcpi`, `rpp_all_items`, and `official_real_pcpi`.

### Step 3 — Adjustment, Ranking, and Validation

**Script:** `code/03_analyze_data.R`.

**Input:** `data/processed/state_income_prices_2024.csv`.

The central transformation is:

$$
\text{RPP-adjusted PCPI}_{s,2024}
= \frac{\text{nominal PCPI}_{s,2024}}{\text{all-items RPP}_{s,2024}/100}.
$$

Rank 1 denotes the highest income. Exact ties receive the better rank through `ties.method = "min"`. Rank change equals nominal rank minus adjusted rank: positive values indicate movement toward rank 1.

The script computes movement counts, median and maximum absolute rank changes, top-ten overlap, and the correlation between nominal income and RPP. It also checks that adjusted ranks match official real-PCPI ranks and that the range of official-to-adjusted ratios is no greater than `0.0001`. It stops before writing outputs if either validation fails.

**Outputs:** `data/processed/state_income_analysis_2024.csv` and `data/processed/rank_summary_2024.csv`.

### Step 4 — Figure Generation

**Script:** `code/04_make_figures.R`.

**Input:** `data/processed/state_income_analysis_2024.csv`.

The script checks 50-state coverage and ranking consistency, converts BEA geographic codes to map identifiers, and obtains 2024 map geometry and labels from the mapping packages. It requires both rankings to contain ranks 1–50, so tied rankings would fail this stage.

**Outputs:** Two maps with a shared ranking color scale and a chart of rank changes, saved as three 300-dpi PNGs in `figures/`.

### Step 5 — Blog Rendering

**Source:** `BlogPost04.qmd`.

The QMD contains narrative, links, and image references; it contains no executable analysis chunks. It embeds the three regenerated figures, two retained ranking PNGs, and `BlogPost04Cover.png`. Quarto rendering does not run scripts 01–04.

## Project Structure

The following structure reflects the supplied folder screenshot. Paths throughout this README are relative to `blog/posts/post4/`, unless stated otherwise.

```text
blog/posts/post4/
├── README.md
├── BlogPost04.qmd
├── BlogPost04Cover.png
├── code/
│   ├── 01_get_raw_data.R
│   ├── 02_clean_data.R
│   ├── 03_analyze_data.R
│   └── 04_make_figures.R
├── data/
│   ├── raw/
│   │   ├── bea_state_annual_income_2025-09-26.zip
│   │   ├── bea_nominal_pcpi_2024.csv
│   │   ├── bea_all_items_rpp_2024.csv
│   │   ├── bea_official_real_pcpi_2024.csv
│   │   └── bea_2024_metadata.rds
│   └── processed/
│       ├── state_income_prices_2024.csv
│       ├── state_income_analysis_2024.csv
│       └── rank_summary_2024.csv
└── figures/
    ├── 01_nominal_pcpi_map_2024.png
    ├── 02_rpp_adjusted_pcpi_map_2024.png
    ├── 03_rank_changes_2024.png
    ├── 01_nominal_pcpi_ranking_2024.png
    └── 02_rpp_adjusted_pcpi_ranking_2024.png
```

## File Guide

### Blog Files

| File | Purpose |
|---|---|
| `BlogPost04.qmd` | Main Quarto article; embeds the cover and all five analytical PNGs without executing R analysis. |
| `BlogPost04Cover.png` | Cover image referenced directly from the post directory. |
| `README.md` | Project documentation and reproduction instructions. |

### Code

| File | Purpose |
|---|---|
| `code/01_get_raw_data.R` | Retrieves three API series and saves CSV snapshots plus metadata; does not download the historical ZIP. |
| `code/02_clean_data.R` | Validates and merges archived income, RPP, and official real income; audits later API income revisions. |
| `code/03_analyze_data.R` | Computes adjusted income, rankings, movements, summary metrics, and official-series validation. |
| `code/04_make_figures.R` | Generates the nominal map, adjusted map, and rank-change chart from analyzed data. |

### Raw Data

| File | Source | Purpose |
|---|---|---|
| `data/raw/bea_state_annual_income_2025-09-26.zip` | BEA Regional Accounts archive, September 26, 2025 release | Fixed nominal-income input; script 02 reads SAINC1 line 3 for 2024 directly from its CSV member. Download date unconfirmed. |
| `data/raw/bea_nominal_pcpi_2024.csv` | BEA API, SAINC1 line 3 | Later nominal-income vintage used for revision auditing; required by script 02. Retrieval timestamp is recorded in the metadata RDS. |
| `data/raw/bea_all_items_rpp_2024.csv` | BEA API, SARPP line 1 | 2024 all-items price index used in the adjustment. Retrieval timestamp is recorded in the metadata RDS. |
| `data/raw/bea_official_real_pcpi_2024.csv` | BEA API, SARPI line 2 | 2024 official real PCPI used for validation. Retrieval timestamp is recorded in the metadata RDS. |
| `data/raw/bea_2024_metadata.rds` | Acquisition metadata saved by script 01 | Preserves source notes, series specifications, production timestamps when supplied, and retrieval time; not read by downstream scripts. |

### Processed Data

| File | Generated By | Purpose |
|---|---|---|
| `data/processed/state_income_prices_2024.csv` | `code/02_clean_data.R` | Cleaned 50-state source measures; input to script 03. |
| `data/processed/state_income_analysis_2024.csv` | `code/03_analyze_data.R` | Adjusted PCPI, ranks, movements, and validation columns; input to script 04. |
| `data/processed/rank_summary_2024.csv` | `code/03_analyze_data.R` | One-row summary of movements, top-ten overlap, correlation, and validation statistics; supports checking reported findings. |

### Figures

| File | Generated By | Purpose |
|---|---|---|
| `figures/01_nominal_pcpi_map_2024.png` | `code/04_make_figures.R` | Nominal income ranking map used in the main article. |
| `figures/02_rpp_adjusted_pcpi_map_2024.png` | `code/04_make_figures.R` | Adjusted income ranking map using the same color scale. |
| `figures/03_rank_changes_2024.png` | `code/04_make_figures.R` | Direction and magnitude of state rank changes. |
| `figures/01_nominal_pcpi_ranking_2024.png` | Not generated by the supplied scripts | Additional nominal-ranking graphic embedded at the end of the article; retain the existing PNG. |
| `figures/02_rpp_adjusted_pcpi_ranking_2024.png` | Not generated by the supplied scripts | Additional adjusted-ranking graphic embedded at the end of the article; retain the existing PNG. |

## How to Reproduce the Analysis

### 1. Clone or Open the Repository

Clone the [website repository](https://github.com/RodgersYe/RodgersYe-Website):

```bash
git clone https://github.com/RodgersYe/RodgersYe-Website.git
cd RodgersYe-Website
```

Open the root RStudio Project, or run the following script commands from the repository root. The post directory must remain at `blog/posts/post4/` so that the scripts' `here::here()` paths resolve correctly.

### 2. Obtain the Required Raw Data

For the published comparison, confirm that `blog/posts/post4/data/raw/` contains the historical ZIP and all three API CSVs listed above. Reusing them requires no API key. Keep the metadata RDS for provenance.

If the historical ZIP is missing, obtain the September 26, 2025 income release from the [BEA archive](https://apps.bea.gov/histdata/RegionalAccounts.html) and save it as `bea_state_annual_income_2025-09-26.zip` in that raw-data directory. It must contain the exact member `SAINC1__ALL_AREAS_1929_2024.csv`. Do not replace it with a current income download when reproducing the published rankings.

If the API snapshots are missing, script 01 can retrieve current 2024 estimates. Register for a [personal BEA API UserID](https://apps.bea.gov/api/signup/), accept the API terms, and set `BEA_API_KEY` in a private repository-root `.Renviron` file. Restart the R session, then run:

```bash
Rscript blog/posts/post4/code/01_get_raw_data.R
```

Fresh downloads are not guaranteed to reproduce the original vintage. If validation fails, restore the original snapshots or investigate the source releases rather than disabling the checks.

Keep `.Renviron` out of Git, and do not commit API keys, request URLs containing them, or full API responses. The acquisition script saves selected metadata rather than the full response.

### 3. Install Required Software and Packages

Install R for the analysis and Quarto for rendering. The provided materials do not specify R, Quarto, or package versions.

Install the packages checked or called by the scripts:

```bash
Rscript -e 'install.packages(c("here", "httr2", "ggplot2", "usmap", "usmapdata", "sf"))'
```

`httr2` is needed only for API acquisition. `here` is used throughout; script 04 requires `ggplot2`, `usmap`, `usmapdata`, and `sf`. The other calls use packages included with R.

### 4. Run the Analysis Scripts

With the required raw snapshots available, run:

```bash
Rscript blog/posts/post4/code/02_clean_data.R
Rscript blog/posts/post4/code/03_analyze_data.R
Rscript blog/posts/post4/code/04_make_figures.R
```

Script 03 depends on script 02's cleaned CSV; script 04 depends on script 03's analyzed CSV. Script 01 can be skipped when saved API snapshots are available, and it never replaces the need for the historical ZIP.

If processed data are already available, script 04 can regenerate the three main figures directly from `state_income_analysis_2024.csv`. If the cleaned input is available, scripts 03–04 can be run without script 02. To reproduce the complete calculations and validation, start at script 02 with the saved raw data.

Check that:

- Script 02 reports 50 processed state rows.
- Script 03 passes the official-ranking and ratio checks and writes both analysis CSVs.
- `rank_summary_2024.csv` reports 44 states changing rank, a median absolute change of four places, and a top-ten overlap of seven, matching the article.
- Script 04 writes the two maps and rank-change PNG.

Retain both additional ranking PNGs: the current scripts do not recreate them.

### 5. Render the Blog

After generating the main figures, confirm that all five analytical PNGs and `BlogPost04Cover.png` are present. From the repository root, run:

```bash
quarto render blog/posts/post4/BlogPost04.qmd
```

The QMD resolves its image references relative to the post directory. Rendering uses the saved images and does not rerun the R pipeline. Rendering within the cloned website also retains its surrounding Quarto configuration.

## Outputs

The pipeline produces three processed CSVs and three main analytical PNGs:

- `state_income_prices_2024.csv` preserves the cleaned inputs to the comparison.
- `state_income_analysis_2024.csv` contains the state-level calculations and values plotted by script 04.
- `rank_summary_2024.csv` provides numerical checks for the article's movement counts and top-ten overlap; the QMD does not import it dynamically.
- The nominal map, adjusted map, and rank-change chart form the main visual evidence in the article.

The QMD also embeds the two existing ranking graphics as additional detail. They are article inputs, but are not outputs of the current four-script pipeline. No separate table or model-output files are produced by these scripts.

## Key Findings

The following are reported in `BlogPost04.qmd` and provide benchmarks for checking a reproduction:

- Wyoming moves from third to first, South Dakota from 13th to fourth, and California from fourth to 12th. Nebraska and North Dakota enter the adjusted top ten.
- Connecticut and Massachusetts rank second and third after adjustment; seven states remain in the top ten under both rankings.
- Forty-four of the 50 states change position, with a median absolute movement of four places.
- Hawaii falls from 20th to 46th, while Iowa and Oklahoma each rise 17 places.

**Main takeaway:** Adjusting for local prices changes some states' positions substantially while preserving much of the nominal ranking; nominal income alone does not provide the complete purchasing-power comparison.

## Limitations

- The comparison covers state averages for 2024, excludes D.C., and does not describe within-state or city-level differences.
- PCPI includes income beyond wages. It is not an individual's expected salary, household income, or household wealth.
- All-items RPP does not represent a particular person's spending pattern, taxes, or chosen city, and the analysis does not evaluate healthcare quality, schools, safety, or commuting.
- Rank changes measure relative positions rather than dollar income gaps. Map colors encode rank rather than the size of income differences.
- Source revisions can change a fresh-download comparison or prevent the fixed-vintage validation checks from passing.
- The supplied scripts regenerate the core calculations and three main figures, but not the two additional ranking PNGs. Their generation cannot be reproduced from the current code alone.
- Exact acquisition dates and software versions have not been verified from the supplied materials; the metadata RDS should be consulted for the API retrieval timestamp.

## Data Attribution and Usage

**Data provider:** U.S. Bureau of Economic Analysis (BEA).

BEA's [reproduction FAQ](https://www.bea.gov/help/faq/145) states that website information is generally in the public domain and may be reproduced without specific permission unless otherwise stated. Source citations are appreciated. Preserve BEA attribution and identify the tables, reference year, historical release, and retrieval information when redistributing the source snapshots.

Suggested project credit: **Data: U.S. Bureau of Economic Analysis, SAINC1, SARPP, and SARPI; 2024 observations. Nominal-income rankings use the September 26, 2025 archived SAINC1 release. Adjusted values and visualizations: author's calculations.**

BEA's [citation guidelines](https://www.bea.gov/help/guidelines-for-citing-bea) request direct links to cited material and prohibit implying BEA endorsement. The [historical archive](https://apps.bea.gov/histdata/RegionalAccounts.html) identifies archived estimates as superseded; they are retained here to reproduce this particular comparison.

API access and use of its content are subject to the [BEA API Terms of Service](https://apps.bea.gov/API/_pdf/bea_api_tos.pdf). These terms call for a prominent notice in services using the API, prohibit implying endorsement, and prohibit presenting modified API content as BEA's own content. Retain the following notice:

> This product uses the Bureau of Economic Analysis (BEA) Data API but is not endorsed or certified by BEA.

The article's public display should also include the notice visibly near its data credit; the supplied QMD currently links to BEA sources but does not contain this notice.

Raw source observations remain identified as BEA data. The project's RPP-adjusted PCPI, rank changes, summaries, and figures are the author's calculations, not BEA-published analytical outputs. The adjusted-PCPI measure is distinct from official real PCPI in constant 2017 dollars.

These third-party data terms are separate from any license applying to the author's code or writing. Map geometry is supplied through installed mapping packages; preserve their applicable notices and terms separately from the BEA data credit.
