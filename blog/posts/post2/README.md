# Blog Post 2: Web Scraping for Actionable Insights

## Research Question

**Which day or days of the week offer the most opportunities among events currently listed on the Drexel University Events Calendar for 2026?**

This project uses web scraping and data analysis to identify which weekdays provide the greatest concentration of event opportunities. The goal is to turn publicly available calendar data into an actionable scheduling insight for people who want to attend more university events.

---

## Data Source

The data were collected from the:

**Drexel University Events Calendar**

https://calendar.drexel.edu/EventList.aspx

The research period is:

**January 1, 2026 – December 31, 2026**

The data were scraped on:

**September 21, 2026**

Because the data were collected before the end of 2026, events scheduled later in the year, especially in November and December, may not yet have been fully posted. This limitation is addressed through robustness checks in the analysis.

---

## Web Scraping

The event data were collected using R and the `rvest` package.

Before scraping, the calendar path was checked against the site's robots rules. The page was publicly accessible without login, CAPTCHA, or other access restrictions.

To reduce the burden on the website:

- Only one monthly calendar page was requested at a time.
- The scraper accessed 12 monthly calendar pages rather than individual event pages.
- A two-second pause was added between requests.

The scraper collected information including:

- Event ID
- Information ID
- Event title
- Event date
- Event URL
- Source month
- Scraping date

The initial scraping process produced **3,869 raw event records**.

---

## Data Cleaning

The raw data were cleaned using `02_clean_analyze.R`.

The main cleaning steps were:

1. Remove events explicitly marked as cancelled.
2. Check for exact duplicate records using event ID, information ID, and event date.
3. Examine multi-day and recurring events.
4. Create weekday and month variables.
5. Identify events occurring before and after the scraping date.

A total of **292 cancelled records**, representing four unique cancelled events, were removed.

No exact duplicate records were found.

The final cleaned dataset contains:

**3,577 event occurrences**

Multi-day and recurring events were retained in the main analysis because the research question focuses on **attendance opportunities**. If an event is available on multiple dates, each listed date represents a possible opportunity to attend.

---

## Main Analysis

The analysis compares event opportunities across weekdays.

Because the seven weekdays do not all occur exactly the same number of times during 2026, the analysis calculates:

**Average listed event opportunities per occurrence of each weekday**

The main results are:

| Weekday | Listed Events | Average Events per Weekday |
|---|---:|---:|
| Tuesday | 707 | 13.60 |
| Wednesday | 701 | 13.48 |
| Thursday | 658 | 12.42 |
| Monday | 466 | 8.96 |
| Friday | 459 | 8.83 |
| Saturday | 331 | 6.37 |
| Sunday | 255 | 4.90 |

Tuesday and Wednesday have the highest concentration of listed event opportunities, with Thursday also relatively event-rich.

---

## Robustness Checks

Two additional analyses were conducted.

### 1. Events occurring by the scraping date

Because future events may not yet be fully posted, the analysis was repeated using only events occurring on or before September 21, 2026.

In this version:

- Wednesday ranked first.
- Tuesday ranked second.
- Thursday ranked third.

### 2. Excluding explicitly labeled multi-day events

The analysis was also repeated after removing events explicitly labeled as multi-day events.

In this version:

- Tuesday ranked first.
- Wednesday ranked second.
- Thursday ranked third.

Across all specifications, the broader pattern remains stable:

**Tuesday and Wednesday consistently provide the greatest concentration of event opportunities, followed by Thursday.**

---

## Actionable Insight

For someone trying to maximize opportunities to attend events listed on the Drexel University Events Calendar, the most useful scheduling strategy is to keep:

**Tuesdays and Wednesdays relatively flexible**

Thursdays are also a strong option.

Weekends, especially Sundays, contain substantially fewer listed event opportunities.

---

## Project Structure

```text
post2/
│
├── README.md
├── BlogPost02Cover.png
├── BlogPost02.qmd
│
├── code/
│   ├── 01_scrape_events.R
│   └── 02_clean_analyze.R
│
├── data/
│   ├── raw/
│   │   └── drexel_events_raw.csv
│   │
│   └── processed/
│       ├── drexel_events_clean.csv
│       ├── weekday_summary.csv
│       ├── weekday_robustness_comparison.csv
│       └── monthly_counts_clean.csv
│
└── figures/
    ├── events_by_weekday.png
    └── weekday_robustness_check.png