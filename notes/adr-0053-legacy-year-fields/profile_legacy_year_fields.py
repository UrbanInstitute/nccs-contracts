"""Full pass over the legacy CORE files (1989 to 2011), one summary row per file.

Reads every row directly from S3 and writes a CSV of population and
agreement counts for STYEAR, FISYR, TAXPER, SOIYR and ACCPER. See
legacy_core.py for why this is Python.

Usage: python3 profile_legacy_year_fields.py OUTPUT.csv
"""
import csv
import sys

from legacy_core import connect, file_scope, file_year, list_legacy_core_files, read_csv_sql

YEAR_COLUMNS = ["STYEAR", "FISYR", "TAXPER", "SOIYR", "ACCPER"]

HEADER = [
    "file", "year", "scope", "rows",
    "styear_pop", "fisyr_pop", "taxper_pop", "soiyr_pop", "accper_pop",
    "taxper_6char", "taxper_4char", "styear_4digit",
    "inferred_eq_styear", "inferred_ne_styear",
    "styear_eq_fisyr", "styear_eq_fileyear", "fisyr_eq_taxper_year", "dec_end_share",
]


def column_expressions(con, name):
    """One SQL expression per year column: trimmed text, or NULL when the file lacks it."""
    describe = f"DESCRIBE SELECT * FROM {read_csv_sql(name)} LIMIT 0"
    present = {row[0].upper(): row[0] for row in con.execute(describe).fetchall()}
    return [
        f'trim("{present[column]}")' if column in present else "CAST(NULL AS VARCHAR)"
        for column in YEAR_COLUMNS
    ]


def summary_sql(name, year, expressions):
    """Count how the year fields are populated and whether they agree with each other."""
    styear, fisyr, taxper, soiyr, accper = expressions
    return f"""
    WITH base AS (
      SELECT {styear} AS s, {fisyr} AS fy, {taxper} AS t, {soiyr} AS o, {accper} AS a
      FROM {read_csv_sql(name)}
    ), parsed AS (
      SELECT *,
        CASE WHEN regexp_matches(t, '^[0-9]{{6}}$') THEN TRY_CAST(substr(t, 1, 4) AS INT)
             WHEN regexp_matches(t, '^[0-9]{{4}}$') THEN 1900 + TRY_CAST(substr(t, 1, 2) AS INT) END AS tyear,
        CASE WHEN regexp_matches(t, '^[0-9]{{6}}$') THEN substr(t, 5, 2)
             WHEN regexp_matches(t, '^[0-9]{{4}}$') THEN substr(t, 3, 2) END AS tmonth,
        CASE WHEN regexp_matches(s, '^[0-9]{{4}}$') THEN TRY_CAST(s AS INT) END AS s_int,
        CASE WHEN regexp_matches(fy, '^[0-9]{{4}}$') THEN TRY_CAST(fy AS INT) END AS f_int
      FROM base
    ), inferred AS (
      SELECT *, CASE WHEN tmonth = '12' THEN tyear ELSE tyear - 1 END AS inferred
      FROM parsed
    )
    SELECT count(*),
      count(*) FILTER (WHERE s <> ''), count(*) FILTER (WHERE fy <> ''), count(*) FILTER (WHERE t <> ''),
      count(*) FILTER (WHERE o <> ''), count(*) FILTER (WHERE a <> ''),
      count(*) FILTER (WHERE regexp_matches(t, '^[0-9]{{6}}$')),
      count(*) FILTER (WHERE regexp_matches(t, '^[0-9]{{4}}$')),
      count(*) FILTER (WHERE s_int IS NOT NULL),
      count(*) FILTER (WHERE inferred = s_int),
      count(*) FILTER (WHERE inferred <> s_int),
      count(*) FILTER (WHERE s_int = f_int),
      count(*) FILTER (WHERE s_int = {year}),
      count(*) FILTER (WHERE f_int = tyear),
      round(count(*) FILTER (WHERE tmonth = '12') * 1.0
            / nullif(count(*) FILTER (WHERE tmonth IS NOT NULL), 0), 3)
    FROM inferred"""


def main(output_path):
    con = connect()
    with open(output_path, "w", newline="") as handle:
        out = csv.writer(handle)
        out.writerow(HEADER)
        for name in list_legacy_core_files():
            year = file_year(name)
            counts = con.execute(summary_sql(name, year, column_expressions(con, name))).fetchone()
            out.writerow([name, year, file_scope(name), *counts])
            print(name, counts[0], file=sys.stderr, flush=True)


if __name__ == "__main__":
    main(sys.argv[1])
