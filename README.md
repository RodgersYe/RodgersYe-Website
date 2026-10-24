# Personal Website and Data Analysis Blog

This [repository](https://github.com/RodgersYe/RodgersYe-Website) contains the source for my personal website and data analysis blog. The website is built with [Quarto](https://quarto.org/), and individual posts include R code, data documentation, and analytical outputs.

This README provides repository navigation and a starting point for reproduction. Each post's own README documents its methods, inputs, dependencies, and limitations in detail.

## Repository Structure

```text
.
├── _quarto.yml          # Website configuration; rendered output goes to docs/
├── index.qmd            # Homepage
├── aboutme.qmd          # About Me page
├── resume.qmd           # Résumé/CV page
├── styles.css           # Shared website styling
├── images/              # Images used by the main website pages
├── blog/
│   ├── index.qmd        # Blog listing page
│   └── posts/
│       ├── post1/       # P-value interpretation and common misconceptions
│       ├── post2/       # Drexel event opportunities
│       ├── post3/       # U.S. working hours by age
│       ├── post4/       # State income and regional prices
│       ├── post5/       # Living alone and rent burden
│       └── post6/       # PSID intergenerational income elasticity (IGE)
├── docs/                # Rendered website served by GitHub Pages
└── README.md
```

Posts 2–6 generally use the following layout, with different scripts and data files in each post:

```text
blog/posts/postX/
├── README.md
├── BlogPostXX.qmd
├── BlogPostXXCover.png
├── code/
├── data/
│   ├── raw/
│   └── processed/
└── figures/
```

## Blog Index

| Post | Topic and coverage | Data source | Documentation |
|---|---|---|---|
| 1 — Misconceptions About the P-Value | P-value interpretation, conditional probability, and a two-sided fair-coin simulation | Simulated coin flips using Python/NumPy; no external dataset | [Post 1 source](blog/posts/post1/BlogPost01.qmd) |
| 2 — Web Scraping for Actionable Insights | Weekday event opportunities listed for 2026; snapshot collected September 21, 2026 | Drexel University Events Calendar | [Post 2 README](blog/posts/post2/README.md) |
| 3 — How Has the American Workweek Changed? | Actual weekly hours across six age groups, 2000–2024 | IPUMS CPS Basic Monthly microdata | [Post 3 README](blog/posts/post3/README.md) |
| 4 — The Price Tag Behind America's Income Rankings | Nominal and regional-price-adjusted per capita personal income in the 50 states, 2024 | BEA archived income and API snapshots | [Post 4 README](blog/posts/post4/README.md) |
| 5 — Is Living Alone Easier Where More People Do It? | Living-alone prevalence and severe rent burden in the 50 states, 2024 | IPUMS USA, ACS one-year microdata; Census state boundaries | [Post 5 README](blog/posts/post5/README.md) |
| 6 — Matching Parents and Children with SQL in Python | Biological parent–child matching, single-year versus multiyear average intergenerational income elasticity, and income-measure sensitivity by age | PSID 2023 Parent Identification, 1968–2023 Cross-Year Individual, and 1999–2023 Family Files | [Post 6 README](blog/posts/post6/README.md) |

## Software and Setup

Clone the repository and work from its root:

```bash
git clone https://github.com/RodgersYe/RodgersYe-Website.git
cd RodgersYe-Website
```

Use R for the analytical scripts and Quarto for the website. RStudio is optional; open the repository's `.Rproj` file if using it. Posts 3–6 resolve paths from the website root with `here`; keep their documented directory locations.

Install the packages needed for the post you want to reproduce:

| Post | Documented R packages |
|---|---|
| 2 | `rvest` for scraping; inspect the scripts for other dependencies |
| 3 | `tidyverse`, `here`, `scales` |
| 4 | `here`, `httr2`, `ggplot2`, `usmap`, `usmapdata`, `sf`; `httr2` is needed only for API acquisition |
| 5 | `here`, `ipumsr`, `data.table`, `tidyselect`, `sf`, `ggplot2`, `scales`, `patchwork`, `ggrepel` |
| 6 | `here`, `reticulate`, `sandwich` (R); `pandas` in the Python environment selected by `reticulate` (Python's `sqlite3` is built in) |

Install Quarto separately. Mapping posts also require the system libraries used by `sf`.

## Reproducing the Analyses

Read the relevant post README first, confirm the required inputs, and run its scripts in the documented order before rendering updated figures. Rendering a page and recalculating its analysis are separate steps.

### Post 2 — Drexel Events

The workflow uses `code/01_scrape_events.R`, followed by `code/02_clean_analyze.R`, within `blog/posts/post2/`.

- **Input:** `data/raw/drexel_events_raw.csv`, collected from 12 monthly calendar pages with a two-second pause between requests.
- **Outputs:** Four processed CSVs, including cleaned events and weekday summaries, plus `events_by_weekday.png` and `weekday_robustness_check.png`.
- **Snapshot check:** The documented data contain 3,869 raw records and 3,577 retained event occurrences after removing cancelled records. Recurring and multi-day occurrences remain in the main analysis.
- **Interpretation:** Comparisons account for the number of times each weekday occurs in 2026. Tuesday and Wednesday consistently have the most listed opportunities, followed by Thursday.

### Post 3 — Working Hours

Obtain an IPUMS CPS Basic Monthly extract covering January 2000–December 2024. Save the uncompressed input as `blog/posts/post3/data/raw/cps_raw.csv`; the scripts do not read the `.csv.gz` directly or download data. Include all variables listed in the post README, including `ASECFLAG`.

From a repository-root R session:

```r
source("blog/posts/post3/code/01_clean_analyze.R")
source("blog/posts/post3/code/02_make_figures.R")
```

The first script writes baseline estimates, audits, endpoint comparisons, and sensitivity CSVs. The second reads `data/processed/annual_age_hours.csv` and generates five PNGs for total, main-job, and other-job hours and the two component shares. No cleaned person-level dataset is exported.

Complete coverage yields 1,800 monthly age-group rows and 150 annual rows, each with 12 observed months. Annual means average the monthly weighted means equally. Results describe workers aged 16+ who were at work in the reference week; the series do not follow a fixed cohort.

To regenerate only figures, run the second script with the correct baseline annual CSV. `BlogPost03.qmd` embeds existing images and does not execute either script. 

### Post 4 — State Income and Prices

Reproduction requires the saved inputs in `blog/posts/post4/data/raw/`:

- `bea_state_annual_income_2025-09-26.zip`, containing `SAINC1__ALL_AREAS_1929_2024.csv`;
- `bea_nominal_pcpi_2024.csv`, `bea_all_items_rpp_2024.csv`, and `bea_official_real_pcpi_2024.csv`.

Keep `bea_2024_metadata.rds` for acquisition provenance. The historical ZIP supplies nominal income for the main rankings; the API nominal-income CSV is used for a revision audit. Adjusted income equals archived nominal PCPI divided by all-items RPP/100. This measure is distinct from BEA's official real PCPI in constant 2017 dollars.

From a repository-root terminal:

```bash
Rscript blog/posts/post4/code/02_clean_data.R
Rscript blog/posts/post4/code/03_analyze_data.R
Rscript blog/posts/post4/code/04_make_figures.R
```

These scripts generate three processed CSVs and three PNGs: two ranking maps and a rank-change chart. Validation requires 50 states and agreement with official real-income rankings. 

Run `01_get_raw_data.R` only when fresh API acquisition is needed; it requires a personal `BEA_API_KEY`, overwrites the API snapshots, and does not obtain the historical ZIP. New vintages may change results or fail validation. Reusing the saved inputs needs no API key.

### Post 5 — Living Alone and Rent Burden

Full reproduction uses the IPUMS USA **2024 ACS one-year sample (`us2024a`)**, including 80 household replicate weights. Keep one matching, unchanged `usa_*.xml` and `usa_*.dat.gz` pair in `blog/posts/post5/data/raw/ipums_2024/`. The DDI XML is required; no CSV conversion is needed.

From a repository-root R session:

```r
options(blog5.ipums_stage = "auto")
for (script in c("01_get_raw_data.R", "02_clean_data.R",
                 "03_analyze_data.R", "04_make_figures.R")) {
  source(here::here("blog", "posts", "post5", "code", script))}
```

Stage `auto` reuses a complete local raw pair, otherwise resumes a saved task or submits and downloads an extract using a personal `IPUMS_API_KEY`. Preserve `extract_id.txt` to resume an interrupted acquisition; task IDs belong to the account that created them.

The final analytical outputs are:

| Output | Files and role |
|---|---|
| One local RDS | `single_person_renters_clean.rds`: cleaned adult one-person renter households and embedded lineage |
| Two aggregate CSVs | `data_validation_report.csv` and `statistical_summary.csv`: consolidated checks and estimates |
| Three PNGs | `fig01_severe_burden_intervals.png`, `fig02_severe_rent_burden_map.png`, and `fig03_living_alone_population_share_map.png` |

Script 03 needs both the raw pair and RDS. Confirm `analysis_completed = PASS` and no `FAIL` entries before using the summary. Script 04 requires both CSVs from a matching completed run and checks the RDS checksum if present. It can regenerate figures without microdata or the RDS; Census boundaries are downloaded only if the geometry ZIP is absent.

Rent burden uses household weights and positive-income adult solo renters; severe burden means annualized gross rent **strictly above 50%** of income. Living-alone prevalence uses person weights and all state residents as its denominator. D.C. is retained separately in reports and excluded from the main 50-state figures. 

**Data access and redistribution:** To comply with IPUMS data-use terms and redistribution restrictions, this repository does not publicly distribute the raw IPUMS microdata or the household-level processed RDS. These files are stored locally and excluded by the documented ignore rules. Public reproduction materials consist of code, aggregate reports, figures, and article assets; they do not replace the microdata required for a full recalculation.

To reproduce the complete analysis when the raw data are not already available:

1. Register for an [IPUMS USA](https://usa.ipums.org/usa/) account and obtain your own personal API key through the [IPUMS Developer Portal](https://developer.ipums.org/).
2. Add `IPUMS_API_KEY=YOUR_PERSONAL_KEY` to a private repository-root `.Renviron` file and restart R. Keep this file and your real key out of Git.
3. Run the four-script sequence above. With `options(blog5.ipums_stage = "auto")`, `01_get_raw_data.R` requests and downloads the specified extract using your own account; the remaining scripts clean, validate, analyze, and plot the data.

If a complete, authorized local XML/data pair is already present, stage `auto` reuses it without requiring an API key. Consult the [Post 5 README](blog/posts/post5/README.md) for the full acquisition instructions and [IPUMS USA terms of use](https://usa.ipums.org/usa/terms.shtml) for data-use requirements. Any license for this repository's code does not grant permission to redistribute IPUMS microdata.

The final QMD's executable chunks and exact image references are not established by the supplied Blog05 documentation; check the saved article before rendering.

### Post 6 — Matching Parents and Children with SQL in Python

The [Post 6 README](blog/posts/post6/README.md) documents the complete PSID data inventory, fixed-width `.txt`/`.do` input pairs, wave-specific income definitions, codebook references, privacy restrictions, and reproduction procedure. The post estimates intergenerational income elasticity (IGE) from biological parents' **combined individual labor earnings** and their adult child's **own labor earnings** (not family income).

- **Identity and linkage:** `PID23` (biological parents), `IND2023ER` (stable individual identifiers, wave-specific family IDs, relationships), and family-level income files.
- **Single-year:** 1999 Family File for parents' 1998 earnings; 2023 Family File for children's 2022 earnings.
- **Multiyear:** parents' earnings from 1998, 2000, 2002, 2004, 2006, 2008, and 2010; children's earnings from 2012, 2014, 2016, 2018, 2020, and 2022. Income is converted to 2022 dollars before averaging, with a minimum of three valid waves in each generation.
- **Methods:** RStudio runs embedded Python (`reticulate` + `pandas`) and SQLite SQL (`SELECT`, `JOIN`, `GROUP BY`, `SUM()`, `AVG()`), followed by R log–log OLS regressions with parent-family clustered standard errors and a clustered bootstrap of the same-sample coefficient difference.

Start from the website repository's `.Rproj` in RStudio, with authorized PSID inputs stored locally in `blog/posts/post6/data/raw/`. Install the packages listed above, ensure Python `pandas` is available, and run:

```r
source(here::here("blog", "posts", "post6", "code", "01_singleyear_prepare_data.R"))
source(here::here("blog", "posts", "post6", "code", "02_singleyear_analyze_ige.R"))
source(here::here("blog", "posts", "post6", "code", "03_multiyear_prepare_data.R"))
source(here::here("blog", "posts", "post6", "code", "04_multiyear_analyze_ige.R"))
```

The scripts write matched row-level records to `data/processed/` (**never distribute**), regression and bootstrap summaries locally, and aggregate-only figures to `figures/`. The updated analysis can also produce `figures/ige_public_summary.csv` for the Quarto page; **review PSID dissemination rules before publishing that file, plots, or other derived statistics**. Codebook PDFs are documentation rather than data files; the private inputs must be acquired separately under PSID's terms.

**PSID licensing restriction:** Its [Conditions of Use](https://simba.isr.umich.edu/u/conduse.aspx) restrict redistribution and explicitly prohibit AI/LLM use in conjunction with PSID data. Do not upload microdata or extracts to GitHub, an AI tool, or other third parties.

## Previewing and Rendering the Website

From the repository root, preview or render the website:

```bash
quarto preview
quarto render
```

To render one post, for example:

```bash
quarto render blog/posts/post3/BlogPost03.qmd
# Or render Blog 06:
quarto render blog/posts/post6/BlogPost06.qmd
```

Confirm that the article's figures and cover are present first. A Quarto render does not itself invoke the external R scripts; execution within a page depends on its QMD contents.

`docs/` contains generated HTML and supporting assets for GitHub Pages. Edit `.qmd`, R, CSS, or other source files, then render again to refresh `docs/`. Keep shared website images in `images/` and post-specific assets in their post directories.

## Data Provenance and Attribution

Saved snapshots, source vintages, and credentials have different roles. Preserve raw data unchanged, retain available extraction metadata, and consult each post README for its full data citation and access instructions. A local file listing does not establish that the file is tracked in Git. Fresh acquisitions and unpinned software may change estimates or output files.
