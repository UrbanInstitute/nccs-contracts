"""Shared helpers for the one-off legacy CORE profiling scripts.

Why Python: these scripts ran once on a temporary EC2 box to read 68
legacy CSVs in full from S3. DuckDB's Python package installs in seconds
with no compiler; R would have cost a long install for a run that was
thrown away. They are evidence of how the numbers were produced, not
pipeline code, so the R convention for producers does not apply.
"""
import re
import subprocess

import duckdb

LEGACY_PREFIX = "s3://nccsdata/legacy/core/"
LEGACY_FILE_PATTERN = re.compile(r"^CORE-(19[89]\d|200\d|201[01])-(.+)\.csv$")


def legacy_core_files(listing_text):
    """Return the legacy CORE file names (1989 to 2011) from an `aws s3 ls` listing."""
    names = [line.split()[-1] for line in listing_text.splitlines() if line.strip()]
    return [name for name in names if LEGACY_FILE_PATTERN.match(name)]


def list_legacy_core_files():
    """List the legacy CORE files currently on S3."""
    listing = subprocess.run(
        ["aws", "s3", "ls", LEGACY_PREFIX], capture_output=True, text=True, check=True
    )
    return legacy_core_files(listing.stdout)


def file_year(name):
    """The four-digit year in a legacy CORE file name."""
    return int(LEGACY_FILE_PATTERN.match(name).group(1))


def file_scope(name):
    """The scope part of a legacy CORE file name, for example 501C3-CHARITIES-PZ."""
    return LEGACY_FILE_PATTERN.match(name).group(2)


def read_csv_sql(name):
    """SQL source clause that reads one legacy file in full, every column as text."""
    return f"read_csv('{LEGACY_PREFIX}{name}', all_varchar=true, sample_size=-1)"


def connect():
    """A DuckDB connection that can read S3 with the instance's credentials."""
    con = duckdb.connect()
    con.execute(
        "SET home_directory='/tmp'; INSTALL httpfs; LOAD httpfs; "
        "CREATE SECRET (TYPE S3, PROVIDER CREDENTIAL_CHAIN);"
    )
    return con
