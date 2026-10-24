# Blog 06 — Matching Parents and Children with SQL in Python

This Quarto blog analyzes intergenerational income elasticity (IGE) using PSID's public-release codebooks and microdata. The program combines RStudio, `reticulate` (Python), SQLite SQL and R regressions.

## Project layout

```text
blog/posts/post6/
├── BlogPost06.qmd
├── README.md
├── code/
│   ├── 01_singleyear_prepare_data.R
│   ├── 02_singleyear_analyze_ige.R
│   ├── 03_multiyear_prepare_data.R
│   └── 04_multiyear_analyze_ige.R
├── data/
│   ├── raw/           # PRIVATE
│   └── processed/
└── figures/           # aggregate graphics and public summary CSV
```

## Data acquisition and definition

Acquire these data files, and place the `.txt` and corresponding Stata `.do` files inside `data/raw/`:

- `PID23.txt` and `PID23.do` — 2023 Parent Identification File.
- `IND2023ER.txt` and `IND2023ER.do` — 1968–2023 Cross-Year Individual File.
- `FAM1999ER`, `FAM2001ER`, `FAM2003ER`, `FAM2005ER`, `FAM2007ER`, `FAM2009ER`, `FAM2011ER`, `FAM2013ER`, `FAM2015ER`, `FAM2017ER`, `FAM2019ER`, `FAM2021ER`, and `FAM2023ER` — each with its `.txt` and matching `.do`.

**Parent income years:** 1998, 2000, 2002, 2004, 2006, 2008, 2010. **Child income years:** 2012, 2014, 2016, 2018, 2020, 2022. The parental earnings definition is the **combined individual labor income of the identified biological parents**; child earnings are those of the identified adult child alone.

The source files do not need to be renamed if they match the filenames above, ignoring capitalization. Do not confuse `.do` fixed-width layouts with `_formats.do` label scripts.

## Environment and execution

Open the parent website `.Rproj` from RStudio; this makes `here::here()` resolve project paths. One-time R installation:

```r
install.packages(c("here", "reticulate", "sandwich"))
```

The Python environment selected by `reticulate` must have `pandas` available; install it into that environment if missing, e.g.:

```r
reticulate::py_install("pandas", pip = TRUE)
```

Run each in order from RStudio Console:

```r
source(here::here("blog", "posts", "post6", "code", "01_singleyear_prepare_data.R"))
source(here::here("blog", "posts", "post6", "code", "02_singleyear_analyze_ige.R"))
source(here::here("blog", "posts", "post6", "code", "03_multiyear_prepare_data.R"))
source(here::here("blog", "posts", "post6", "code", "04_multiyear_analyze_ige.R"))
```

Then preview/render `BlogPost06.qmd` in RStudio.

## Outputs

| Location | Meaning | Public repository? |
|---|---|---|
| `data/processed/ige_single_year.csv` | matched single-year, row-level data | **No** |
| `data/processed/ige_results.csv` | single-year regression summary | keep local by default |
| `data/processed/ige_multi_year.csv` | matched multiyear, row-level data | **No** |
| `data/processed/ige_multiyear_results.csv` | single vs. multiyear coefficients | keep local by default |
| `data/processed/ige_multiyear_difference.csv` | paired bootstrap uncertainty | keep local by default |
| `figures/ige_by_child_age.png` | single-year age profile | aggregate-only; verify release permission |
| `figures/ige_multiyear_only.png` | multiyear age profile | aggregate-only; verify release permission |
| `figures/ige_single_vs_multiyear.png` | common-sample comparison | aggregate-only; verify release permission |
| `figures/ige_public_summary.csv` | only eight aggregate regression rows + bootstrap bounds | aggregate-only; verify release permission |

## Terms, GitHub, and citations

PSID does not permit transferring public-use data or custom extracts to third parties; it also explicitly prohibits using AI/LLM programs in conjunction with PSID data.