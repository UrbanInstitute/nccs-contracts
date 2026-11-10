# How NCCS data moves: from the IRS to nccs.urban.org

Written for someone new to NCCS. It explains where our data comes from,
what we do to it, where it is kept, and where it ends up. Read this
before `ARCHITECTURE.md`, which goes into more detail.

Last checked 9 November 2026.

## The short version

The IRS publishes several free files about tax-exempt organizations.
NCCS copies each file into its own storage, cleans and combines it with
earlier years, and publishes the result as data files anyone can
download. Our R package, the Sector In Brief dashboard, and the
nccs.urban.org website all read from those published files. Nothing
reads from the IRS directly except the first copying step.

## Step 1: what the IRS publishes

| IRS file | What it is | How often | What NCCS makes from it |
|---|---|---|---|
| Business Master File (BMF) | The IRS list of every registered tax-exempt organization: name, address, type, size class | Monthly | The BMF datasets |
| SOI extracts | Yearly spreadsheets of the main Form 990, 990-EZ and 990-PF figures, from 2012 on | Yearly | The CORE datasets |
| E-filed returns | The full text of every electronically filed Form 990, as XML files | Several releases a year | The e-file 990 tables |
| Smaller lists | Organizations that lost exemption, Pub 78 (eligible for tax-deductible gifts), 990-N postcard filers, and similar | Monthly | Published as lists, mostly as received |

Two things come from elsewhere: geography (Census boundaries, used to
place each organization in a county and metro area) and older NCCS
files from before 2012, which we keep to extend the record back to 1989.

## Step 2: copying the IRS files

Small automated programs (called collectors) check the IRS website each
month and copy any new file into NCCS storage, unchanged. Their code is
in the `nccs-lambda` repository. If a monthly update is missing, this is
the first place to look.

## Step 3: cleaning and combining

Each dataset has its own code repository that turns the raw IRS files
into something usable. A repository is a folder of code with its own
history and its own `README.md` and `CLAUDE.md` that explain how to run
it.

| Repository | What it produces |
|---|---|
| `nccs-data-bmf` | The monthly BMF, cleaned and standardized. The Unified BMF: one row per organization covering every month since 1989. The geocoded version with latitude and longitude. Geography crosswalks (tables linking organizations to counties and metro areas) and lookup tables for the codes. |
| `nccs-data-core` | CORE: the yearly Form 990 figures, with the 2012-on IRS extracts and the 1989 to 2011 NCCS files combined into one series with the same column names throughout. |
| `nccs-data-efile` | Our own extraction from the e-filed returns. Today it covers two measures (government grants and program-related investments) used by the dashboard. The full e-file 990 tables on the website are built by Jesse Lecy's `ef2` package from the Nonprofit Open Data Collective, which starts from GivingTuesday's copy of the IRS files. |

Each published file comes with a small record of what it was built from
(the code version, the input files, the row count). This is how we check
that a file is what we think it is.

## Step 4: where the data is kept

The data lives in three storage areas on Amazon Web Services (each one
is called a bucket). Anyone can download from them without an account.

| Bucket | What is in it |
|---|---|
| `nccsdata` | The main one. Raw IRS copies, the cleaned BMF and CORE datasets, the Unified and geocoded BMF, crosswalks, lookup tables, the dashboard's data, and our own e-file extracts. |
| `nccs-efile` | The e-file 990 tables built with the `ef2` package (current release `efile_v3_1`, tax years 2009 to 2025), including the files behind the website's e-file pages. |
| `nccs-data-archive` | Retired copies of old files, kept so nothing is lost. Do not use for new work. |

Within `nccsdata`, the rule is simple: `raw/` holds IRS files as
received, `processed/` holds cleaned data, `unified/` and `geocoding/`
hold the combined BMF, and `latest/` inside a folder always points to
the current version.

## Step 5: who reads the published data

| Reader | What it does |
|---|---|
| `nccsdata` (R package) | Lets researchers load the BMF and CORE straight from storage in R. |
| `sector-in-brief-data` and `sector-in-brief` | Build the numbers behind the Sector In Brief dashboard, then show them. The dashboard is pinned to one dated version of the data. |
| `nccs` (the website) | nccs.urban.org. Each dataset has a page describing it, and the catalog pages list every downloadable file. |

## Step 6: how changes are agreed

The `nccs-contracts` repository (this one) holds one short file per
published dataset saying where it lives, what columns it has, and who
reads it. A change to any of those is agreed here first, and the reason
is written down in `decisions/`. A monthly data governance committee
reviews these changes. The process document on Box, "NCCS process,
reviewers and roles", says who reviews what.

## Where to look when something is wrong

- A monthly BMF file did not arrive: the collectors (`nccs-lambda`).
- A BMF number looks wrong: `nccs-data-bmf`, starting with its quality
  reports in `docs/quality-reports/`.
- A CORE figure looks wrong: `nccs-data-core`.
- The dashboard shows old data: `sector-in-brief-data`, which decides
  the version the dashboard reads.
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
