# Blog 07 — Population Growth and Real GDP

This folder contains the Quarto blog post and **both original interactive Plotly HTML figures** supplied for the assignment, as well as the analysis CSV used to check the reported numbers.

## Local rendering

1. Install [Quarto](https://quarto.org/) if needed.
2. Keep `Blog07_Population_GDP.qmd` and the `figures/` directory together, preserving the paths shown below.
3. Open the folder as your working directory. In a terminal run:

   ```sh
   quarto render Blog07_Population_GDP.qmd --to html
   ```

4. Open the resulting `Blog07_Population_GDP.html` in a browser. Both Plotly widgets are embedded through local iframes, retaining hover details and year controls.

## Files

```
Blog07_Population_GDP.qmd
figures/
  figure_01_population_share_by_state.html
  figure_02_population_vs_real_gdp_2000_2025.html
data/
  Analysis_Results.csv
README.md
```

### If you copy the QMD into an existing Quarto blog

Copy the `figures` directory **alongside** the QMD. If the QMD is moved to a different folder, update both `src="figures/..."` iframe paths and the YAML `resources` paths relative to its new location. Quarto's `resources` list helps retain the HTML figure files during website publication. Do not enable `embed-resources: true` and assume it will automatically absorb each nested iframe into the main HTML; keep the original figure HTML files published alongside the post.

### Replication repository

For the instructor's reproducibility criterion, include your existing R scripts (`01_get_raw_data.R`, `02_clean_data.R`, `03_analyze_data.R`, figure-generation scripts) and a replication README in your GitHub repository. **Do not upload `.Renviron` or your FRED API key.** The folder here is a ready-to-render blog bundle, not a substitute for the entire code repository.
