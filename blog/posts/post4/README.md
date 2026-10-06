# Blog Post 4: The Price Tag Behind America's Income Rankings

This project asks whether the 50 states with the highest **nominal per capita 
personal income (PCPI)** keep their positions after accounting for local prices.
It compares 2024 PCPI with 2024 all-items regional price parities (RPPs), then 
maps the two rankings and each state's change in rank. A state average is not a 
job offer, household income, or a measure of overall quality of life.

The main transformation is:

\[
\text{RPP-adjusted PCPI}_{s,2024}
= \frac{\text{nominal PCPI}_{s,2024}}{\text{all-items RPP}_{s,2024}/100}.
\]

The comparison covers the 50 states; it excludes the District of Columbia and 
the U.S. aggregate. Rank 1 is the highest PCPI. A positive rank change means a 
state moves toward rank 1 after adjustment. The adjustment is this project's 
calculation, **not a BEA-published series**. In particular, it is distinct from 
BEA's real PCPI in constant 2017 dollars.

## Data sources, dates, and permitted use

**Source: U.S. Bureau of Economic Analysis (BEA).** The archived income data 
come from BEA's [Regional Economic Accounts data archive]
(https://apps.bea.gov/histdata/RegionalAccounts.html); 
the other three raw CSV files were retrieved from the 
[BEA Data API, Regional dataset](https://apps.bea.gov/api/signup/). 
BEA's [state personal income](https://www.bea.gov/data/income-saving/personal-income-by-state) 
and [regional price parity](https://www.bea.gov/data/prices-inflation/regional-price-parities-state-and-metro-area) 
pages explain the underlying measures. The **reference year is 2024** for every 
series. The income ZIP is the **September 26, 2025 release**. The API CSV 
filenames identify the reference year but do not identify the API retrieval 
date or a fixed BEA release; if `bea_2024_metadata.rds` is retained, its 
`retrieved_at_utc` records when the script fetched those CSVs. The script also 
records BEA's API production timestamps when supplied. Do not treat the 
retrieval date as the release date.

BEA says that, unless otherwise stated, information on its website is in the 
public domain and may be reproduced without specific permission; it appreciates 
a source citation. See BEA's [reproduction FAQ](https://www.bea.gov/help/faq/145)
and [citation guidelines](https://www.bea.gov/help/guidelines-for-citing-bea). 
The [BEA API Terms of Service](https://apps.bea.gov/API/_pdf/bea_api_tos.pdf) 
apply when using the API. They call for a prominent notice in services that use 
it, prohibit implying BEA endorsement, and prohibit modifying API content while 
still presenting the modified content as BEA's own. Accordingly, the raw files 
are identified as BEA data, whereas the adjusted values, rankings, and figures 
are identified as calculations made for this project. The BEA logo is not used.

> This product uses the Bureau of Economic Analysis (BEA) Data API but is not 
endorsed or certified by BEA.

If this project is displayed through the public website, place the same notice 
visibly near the article's data credit as well; a repository README by itself 
is not prominent on the rendered article page.

BEA's historical archive notes that archived estimates have been superseded by 
later revisions. The dated ZIP is kept intentionally so that readers can 
reproduce the **published comparison**, not accidentally substitute today's 
revised income series. The later API income CSV is used to audit revisions; 
it does not replace the ZIP in the main ranking.

## File guide

Paths in this table are relative to `blog/posts/post4/` in the website repository.

| File | Purpose and provenance |
| --- | --- |
| `BlogPost04.qmd` | Quarto article. It embeds the two map PNGs and the rank-change PNG; it does not execute the R analysis. |
| `BlogPost04Cover.png` | Square cover visible in the local project screenshot; an editorial illustration, not a BEA data visualization. See the cover path note below. |
| `README.md` | This file: sources, file descriptions, and reproduction instructions. |
| `code/01_get_raw_data.R` | Retrieves three 2024 BEA Regional API series with a reader's own API key; writes three raw CSVs and the metadata RDS. It **does not download the historical income ZIP**. |
| `code/02_clean_data.R` | Reads the income ZIP and all three API CSVs; validates year, units, geographies, and 50-state coverage; saves the merged state-level data. It uses the newer API PCPI only for a revision audit. |
| `code/03_analyze_data.R` | Calculates adjusted PCPI, both rankings, rank changes, and summary metrics. Checks the result against BEA's official real PCPI ranking and the expected ratio consistency; saves two analysis CSVs. |
| `code/04_make_figures.R` | Reads the analyzed state data and writes the three PNGs used in the article. Map geography comes from the `usmap`/`usmapdata` packages, not another file in `data/raw/`. |
| `data/raw/bea_state_annual_income_2025-09-26.zip` | BEA historical Regional Accounts release dated **September 26, 2025**. The script reads `SAINC1__ALL_AREAS_1929_2024.csv` inside it, selecting SAINC1 line 3, 2024 PCPI in dollars. This is the **nominal-income input for the published rankings** and must be supplied separately: script 01 does not create it. |
| `data/raw/bea_nominal_pcpi_2024.csv` | BEA Regional API, SAINC1 line 3, year 2024, dollars. A later API vintage used by script 02 to measure revisions relative to the dated ZIP; it is **not** the nominal-income input to the published rankings. Created by script 01. |
| `data/raw/bea_all_items_rpp_2024.csv` | BEA Regional API, SARPP line 1, year 2024, all-items RPP index. The **price-adjustment input**. Created by script 01. |
| `data/raw/bea_official_real_pcpi_2024.csv` | BEA Regional API, SARPI line 2, year 2024, official real PCPI in constant 2017 dollars. Used as an **independent validation input**, not as the article's adjusted-PCPI formula. Created by script 01. |
| `data/raw/bea_2024_metadata.rds` | Selected BEA API table/line/year, units, notes, production timestamps, and script retrieval time. Created by script 01; scripts 02–04 do not read it. It contains no API key by design. |
| `data/processed/state_income_prices_2024.csv` | Script 02 output: one cleaned row per state with archived nominal PCPI, RPP, and official real PCPI. Input to script 03. |
| `data/processed/state_income_analysis_2024.csv` | Script 03 output: adjusted PCPI, nominal and adjusted ranks, rank change, and validation columns for each state. Input to script 04. |
| `data/processed/rank_summary_2024.csv` | Script 03 output: 50-state counts, median and maximum absolute rank changes, top-ten overlap, correlation, and validation statistics. |
| `figures/01_nominal_pcpi_map_2024.png` | Nominal PCPI ranking map, generated by script 04 and used in the article. |
| `figures/02_rpp_adjusted_pcpi_map_2024.png` | RPP-adjusted PCPI ranking map, generated by script 04 and used in the article. Both maps use the same ranking color scale. |
| `figures/03_rank_changes_2024.png` | State rank changes, generated by script 04 and used in the article. |
| `figures/01_nominal_pcpi_ranking_2024.png` | Additional ranking graphic shown in the project folder. The current QMD does not use it, and script 04 does not regenerate it; it is optional for this reproduction path. |
| `figures/02_rpp_adjusted_pcpi_ranking_2024.png` | Additional adjusted-ranking graphic. The current QMD does not use it, and script 04 does not regenerate it; it is optional for this reproduction path. |


## Reproduce the published figures

1. Clone the website repository and open its **root RStudio Project** (or run 
the commands below from the repository root). Have R installed. Install the 
packages used by the four scripts: `here`, `httr2`, `ggplot2`, `usmap`, 
`usmapdata`, and `sf`. Quarto is needed to render the article, not to calculate 
the figures.
2. Confirm that the four source files listed in `data/raw/`—the ZIP and the 
three CSVs—are present. This is the most reliable route to the fixed published 
result. No API key is needed to start at script 02.
3. Run the scripts in order:

   ```bash
   Rscript blog/posts/post4/code/02_clean_data.R
   Rscript blog/posts/post4/code/03_analyze_data.R
   Rscript blog/posts/post4/code/04_make_figures.R
   ```

4. Script 02 should report 50 state rows. Script 03 should pass its 
official-real-PCPI checks; if it stops with a vintage mismatch, inspect the raw 
file versions rather than disabling the checks. Verify that script 04 regenerated 
the three article PNGs in `figures/`.

To fetch the **current** API series yourself instead, 
[register for a personal BEA API UserID](https://apps.bea.gov/api/signup/), 
accept BEA's API terms, and set `BEA_API_KEY` in a repository-root `.Renviron` file. 
Restart R, then run `Rscript blog/posts/post4/code/01_get_raw_data.R`. 
Never commit `.Renviron`, a key, a request URL containing the key, or a full 
API response. Put `.Renviron` in the repository's `.gitignore`; if Git already 
tracks it, remove it from the index before committing. Script 01 overwrites the 
three CSV snapshots, while it does not recreate the dated ZIP. Later BEA 
revisions can therefore change results or cause script 03's vintage checks to 
stop. To reproduce this article exactly, use the committed raw snapshots instead.

## Interpretation

The data compare state averages for a single year. They do not estimate an 
individual's salary, city-level expenses, taxes, household wealth, or overall 
living standards. The maps encode **rank**, not the dollar gap between states. 
The figures and conclusions are the author's analysis of BEA source data; they 
are not official BEA rankings or endorsements.
