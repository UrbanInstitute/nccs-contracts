"""Two follow-up questions after profile_legacy_year_fields.py.

1. Which year do each file's rows belong to? (file year versus FISYR,
   STYEAR and the TAXPER year)
2. In CORE-1999-501C3-CHARITIES-PZ.csv, how do the TAXPER year, STYEAR
   and FISYR line up? (the broken-TAXPER case, backlog U13)

Writes one CSV per question. See legacy_core.py for why this is Python.

Usage: python3 followup_file_year_and_1999.py ALIGNMENT.csv NINETEEN99.csv
"""
import csv
import sys

from legacy_core import connect, file_year, list_legacy_core_files, read_csv_sql

ALIGNMENT_HEADER = [
    "file", "rows", "fisyr_eq_fileyear", "fisyr_eq_fileyear_plus1",
    "fisyr_eq_fileyear_minus1", "styear_eq_fileyear_minus1", "taxper_year_eq_fileyear",
]
BROKEN_1999_FILE = "CORE-1999-501C3-CHARITIES-PZ.csv"
BREAKDOWN_1999_HEADER = ["taxper_year", "styear", "fisyr", "rows"]


def alignment_sql(name, year):
    """Count rows whose year fields match the year in the file name, or a neighbour."""
    return f"""SELECT count(*),
      count(*) FILTER (WHERE TRY_CAST(trim("FISYR") AS INT) = {year}),
      count(*) FILTER (WHERE TRY_CAST(trim("FISYR") AS INT) = {year} + 1),
      count(*) FILTER (WHERE TRY_CAST(trim("FISYR") AS INT) = {year} - 1),
      count(*) FILTER (WHERE TRY_CAST(trim("STYEAR") AS INT) = {year} - 1),
      count(*) FILTER (WHERE TRY_CAST(substr(trim("TAXPER"), 1, 4) AS INT) = {year})
      FROM {read_csv_sql(name)}"""


def breakdown_1999_sql():
    """The most common TAXPER year, STYEAR and FISYR combinations in the broken file."""
    return f"""SELECT substr(trim("TAXPER"), 1, 4), trim("STYEAR"), trim("FISYR"), count(*) AS n
      FROM {read_csv_sql(BROKEN_1999_FILE)}
      GROUP BY 1, 2, 3 ORDER BY n DESC LIMIT 12"""


def write_csv(path, header, rows):
    with open(path, "w", newline="") as handle:
        out = csv.writer(handle)
        out.writerow(header)
        out.writerows(rows)


def main(alignment_path, breakdown_path):
    con = connect()
    alignment_rows = []
    for name in list_legacy_core_files():
        counts = con.execute(alignment_sql(name, file_year(name))).fetchone()
        alignment_rows.append([name, *counts])
        print(name, counts[0], file=sys.stderr, flush=True)
    write_csv(alignment_path, ALIGNMENT_HEADER, alignment_rows)
    write_csv(breakdown_path, BREAKDOWN_1999_HEADER, con.execute(breakdown_1999_sql()).fetchall())


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
