# How NCCS data moves: from the IRS to nccs.urban.org

NCCS takes the free files the IRS publishes about tax-exempt
organizations, cleans them, combines them with earlier years, and
publishes the result as data files anyone can download. Our R package,
the Sector In Brief dashboard and the nccs.urban.org website all read
from those published files.

This is a short overview for someone joining the team. `ARCHITECTURE.md`
has the detail. Last checked 9 November 2026.

## Step 1: what the IRS publishes

| IRS file | What it is | How often | What NCCS makes from it |
|---|---|---|---|
| Business Master File (BMF) | The IRS list of every registered tax-exempt organization: name, address, type, size class | Monthly | [The BMF datasets](https://nccs.urban.org/nccs/datasets/bmf/) |
| Statistics of Income (SOI) extracts | Yearly spreadsheets of the main Form 990, 990-EZ and 990-PF figures, from 2012 on | Yearly | [The CORE datasets](https://nccs.urban.org/nccs/datasets/core/) |
| E-filed returns | The full content of every electronically filed Form 990, as XML files (a plain-text format that computers read, not people) | Several releases a year | [The e-file 990 tables](https://nccs.urban.org/nccs/datasets/efile/) |
| Smaller lists | Organizations that lost exemption, Pub 78 (eligible for tax-deductible gifts), 990-N postcard filers, and similar | Monthly | Published as lists, mostly as received (see the [dataset catalog](https://nccs.urban.org/nccs/datasets/)) |

Two things come from elsewhere: geography (Census boundaries, used to
place each organization in a county and metro area) and older NCCS
files from before 2012, which we keep to extend the record back to 1989.

## Step 2: getting the IRS files

Each pipeline retrieves the source files it needs.
[`nccs-lambda`](https://github.com/UI-Research/nccs-lambda) collects the
monthly BMF and several smaller IRS lists with small automated programs
that run each month. CORE and e-file data have separate download steps
inside their own repositories. If a monthly BMF update is missing,
`nccs-lambda` is the first place to look.

## Step 3: cleaning and combining

Each dataset has its own code repository that turns the IRS files into
something usable. A repository is a folder of code with its own history.
Each repository's README explains how to run it.

| Repository | What it produces |
|---|---|
| [`nccs-data-bmf`](https://github.com/UrbanInstitute/nccs-data-bmf) | The monthly BMF, cleaned and standardized. The Unified BMF, which combines the available historical files into one row per organization with summary information about its history. The geocoded version with latitude and longitude. Geography crosswalks (tables linking organizations to counties and metro areas) and lookup tables for the codes. |
| [`nccs-data-core`](https://github.com/UrbanInstitute/nccs-data-core) | CORE: the yearly Form 990 figures, with the 2012-on IRS extracts and the 1989 to 2011 NCCS files combined into one series with the same column names throughout. |
| [`ef2`](https://github.com/Nonprofit-Open-Data-Collective/ef2) (Jesse Lecy, Nonprofit Open Data Collective) | The e-file 990 tables: every e-filed Form 990, 990-EZ and 990-PF turned into tables, one per part of the form. It starts from GivingTuesday's copy of the IRS files. NCCS hosts the results. |

The main processed datasets include a build record showing the code
version, the input files and the row counts. Older and externally
produced files do not all have one.

## Step 4: where the data is kept

The data lives in three storage areas on Amazon Web Services (each one
is called a bucket). Anyone can download from them without an account.

| Bucket | What is in it |
|---|---|
| `nccsdata` | The main one. IRS files as received, the cleaned BMF and CORE datasets, the Unified and geocoded BMF, crosswalks, lookup tables, and the dashboard's data. |
| `nccs-efile` | The e-file 990 tables built with the `ef2` package (current release `efile_v3_1`, tax years 2009 to 2025), including the files behind the website's e-file pages. |
| `nccs-data-archive` | Retired copies of old files, kept so nothing is lost. Do not use for new work. |

Within `nccsdata`: `raw/` holds IRS files as received, `processed/`
holds cleaned data, `unified/` and `geocoding/` hold the combined BMF,
and `latest/` inside a folder points to the current version.

## Step 5: who reads the published data

| Reader | What it does |
|---|---|
| [`nccsdata`](https://github.com/UrbanInstitute/nccsdata) (R package) | Lets researchers load the BMF and CORE straight from storage in R. [Package guide](https://urbaninstitute.github.io/nccsdata/). |
| [`sector-in-brief-data`](https://github.com/UrbanInstitute/sector-in-brief-data) and [`sector-in-brief`](https://github.com/UrbanInstitute/sector-in-brief) | The first builds the numbers behind the [Sector In Brief dashboard](https://urban-main.shinyapps.io/sector-in-brief/); the second shows them. The dashboard is pinned to one dated version of the data. [About the dashboard](https://nccs.urban.org/nccs/resources/sector-in-brief-dashboard/). |
| [`sector-in-brief-api`](https://github.com/UrbanInstitute/sector-in-brief-api) (download service) | Lets a user or a program ask for a custom slice of the BMF or CORE data and get back a download link, without downloading whole files. |
| [`nccs`](https://github.com/UrbanInstitute/nccs) (the website) | [nccs.urban.org](https://nccs.urban.org/). Each dataset has a [page describing it](https://nccs.urban.org/nccs/datasets/), the [catalog pages](https://nccs.urban.org/nccs/catalogs/) list every downloadable file, and the [changelog](https://nccs.urban.org/nccs/changelog/) records data changes. The [terms page](https://nccs.urban.org/nccs/terms/) says how the data may be used. |

## Step 6: how changes are agreed

This repository, `nccs-contracts`, holds one short file per published
dataset saying where it lives, what columns it has, and who reads it. A
change to any of those is agreed here first, and the reason is written
down in `decisions/`. A monthly data governance committee reviews these
changes. The process document on Box, "NCCS process, reviewers and
roles" (in Data Engineering / Data Engineering Processes), says who
reviews what.

## Where to look when something is wrong

- A monthly BMF file did not arrive: `nccs-lambda`.
- A BMF number looks wrong: `nccs-data-bmf`, starting with its quality
  reports in `docs/quality-reports/`.
- A CORE figure looks wrong: `nccs-data-core`.
- The dashboard shows old data: check whether `sector-in-brief-data` has
  published an update, and whether `sector-in-brief` is using that
  version.
- A website page is out of date: `nccs`, where catalog pages are rebuilt
  by hand and can lag behind storage.

## Known gaps

- The e-file 990 tables depend on GivingTuesday's copy of the IRS files,
  which has run behind the IRS. Reducing that dependence is under
  discussion for 2027.
- The smaller IRS lists are published largely as received and have no
  cleaning step of their own.
- Website catalog pages are rebuilt by hand, so they can show fewer files
  than storage actually holds.
