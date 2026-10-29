# Personal Website and Data Analysis Blog

This repository contains the source files and rendered output for my personal website and data analysis blog, built with [Quarto](https://quarto.org/) and published through GitHub Pages.

> **Website repository, not a research-reproduction repository.** This repository is used to build and publish the website. It contains blog articles and the figures or other assets needed to display them, but **does not contain the full research code or datasets required to reproduce the analyses**. For reproducibility, use the separate research repositories linked in the [Blog Index](#blog-index).

The website includes a homepage, an About Me page, a résumé page, and a blog. The blog is planned to contain **11 posts**. Source files for Blogs 01–07 are currently organized in this repository; entries for Blogs 08–11 are reserved for future updates.

## Repository Structure

```text
.
├── _quarto.yml          # Quarto website configuration
├── index.qmd            # Homepage
├── aboutme.qmd          # About Me page
├── resume.qmd           # Résumé/CV page
├── styles.css           # Website styling
├── images/              # Shared website images
├── blog/
│   ├── index.qmd        # Blog listing page
│   └── posts/
│       ├── post1/       # Blog 01 article and display assets
│       ├── post2/       # Blog 02 article and display assets
│       ├── post3/       # Blog 03 article and display assets
│       ├── post4/       # Blog 04 article and display assets
│       ├── post5/       # Blog 05 article and display assets
│       ├── post6/       # Blog 06 article and display assets
│       └── post7/       # Blog 07 article and display assets
├── docs/                # Generated website output for GitHub Pages
└── README.md
```

The `blog/posts/postN/` folders hold the corresponding Quarto article (`.qmd`) and any images or interactive assets displayed on the website. They are **not** intended to serve as complete research projects. The `docs/` directory is produced by rendering the Quarto website; it is not the place to edit article source content.

*Blogs 08–11 do not have directories here yet. The placeholders below reserve entries in this README, not empty folders in the repository.*

## Blog Index

| Blog | Article / topic | Website article source | Research code, data, and reproduction instructions |
|---|---|---|---|
| 01 | **Misconceptions About the P-Value** — interpretation of p-values | [BlogPost01.qmd](blog/posts/post1/BlogPost01.qmd) | **Not applicable** — no separate repository; the article does not require an external data-processing workflow. |
| 02 | **Web Scraping for Actionable Insights** — Drexel University event listings | [BlogPost02.qmd](blog/posts/post2/BlogPost02.qmd) | [Blog 02 research repository](https://github.com/RodgersYe/RodgersYe_6400_Blog02) |
| 03 | **How Has the American Workweek Changed?** — working hours by age | [BlogPost03.qmd](blog/posts/post3/BlogPost03.qmd) | [Blog 03 research repository](https://github.com/RodgersYe/RodgersYe_6400_Blog03) |
| 04 | **The Price Tag Behind America's Income Rankings** — state income and regional prices | [BlogPost04.qmd](blog/posts/post4/BlogPost04.qmd) | [Blog 04 research repository](https://github.com/RodgersYe/RodgersYe_6400_Blog04) |
| 05 | **Is Living Alone Easier Where More People Do It?** — living alone and rent burden | [BlogPost05.qmd](blog/posts/post5/BlogPost05.qmd) | [Blog 05 research repository](https://github.com/RodgersYe/RodgersYe_6400_Blog05) |
| 06 | **Matching Parents and Children with SQL in Python** — intergenerational income elasticity using PSID | [BlogPost06.qmd](blog/posts/post6/BlogPost06.qmd) | [Blog 06 research repository](https://github.com/RodgersYe/RodgersYe_6400_Blog06) |
| 07 | **More Population, More Prosperity?** — state population and real GDP growth | [BlogPost07.qmd](blog/posts/post7/BlogPost07.qmd) | [Blog 07 research repository](https://github.com/RodgersYe/RodgersYe_6400_Blog07) |
| 08 | **To be announced** | Not yet available | Repository link to be added |
| 09 | **To be announced** | Not yet available | Repository link to be added |
| 10 | **To be announced** | Not yet available | Repository link to be added |
| 11 | **To be announced** | Not yet available | Repository link to be added |

## How to Reproduce a Blog's Analysis

For **Blogs 02–07**, follow the matching research-repository link in the table above. Each separate repository is the reference point for that blog's available scripts, data materials, software requirements, data sources, and step-by-step reproduction instructions.

1. Open or clone the **individual blog research repository**, rather than using this website repository as the analysis workspace.
2. Read that repository's `README.md` for its required inputs, dependencies, and execution order.
3. Obtain any data that are **not publicly redistributable** from the original provider, following the provider's access requirements and terms of use. A public research repository does not necessarily include restricted raw microdata.
4. Run the analysis in the research repository as documented, then compare the generated results with the figures and discussion on the website.

**Blog 01** has no separate research repository because it does not require a standalone data-processing pipeline. **Blogs 08–11** will receive article and reproduction links as they are developed and published.

Rendering an existing Quarto article is **not the same as** recreating the underlying research. The website repository primarily contains presentation-ready content and assets; analytical workflows belong to the corresponding research repositories.

## Previewing and Rendering the Website

Install [Quarto](https://quarto.org/docs/get-started/) and run these commands from the root of this website repository:

```bash
quarto preview    # Preview the website locally
quarto render     # Render the website into docs/
```

The rendered HTML and supporting files in `docs/` are used for GitHub Pages publication. Edit the appropriate `.qmd`, CSS, or asset files, then render again to update the generated output. If GitHub Pages is configured to publish from `docs/`, commit and push the updated rendered files as part of the deployment workflow.

To add a future blog, create its article and display assets under `blog/posts/postN/`, update the blog listing or configuration if necessary, and replace that blog's placeholder in the [Blog Index](#blog-index) with its title, article link, and (where applicable) separate research-repository link.

## Data Access and Attribution

The original data sources, any access restrictions, citations, and reproduction details are documented in each blog's **research repository**. Some underlying datasets require independent authorization and cannot be redistributed through GitHub. Please consult the relevant research README and data-provider terms before downloading, using, or sharing any restricted data.
