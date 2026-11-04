"""Tests for the pure parts of legacy_core (no S3 needed)."""
from legacy_core import file_scope, file_year, legacy_core_files

LISTING = """2025-01-01 10:00:00  1234 CORE-1989-501C3-CHARITIES-PZ.csv
2025-01-01 10:00:00  1234 CORE-2011-501CE-NONPROFIT-PZ.csv
2025-01-01 10:00:00  1234 CORE-2012-501C3-CHARITIES-PZ.csv
2025-01-01 10:00:00  1234 README.txt

"""


def test_keeps_only_1989_to_2011_core_files():
    assert legacy_core_files(LISTING) == [
        "CORE-1989-501C3-CHARITIES-PZ.csv",
        "CORE-2011-501CE-NONPROFIT-PZ.csv",
    ]


def test_year_and_scope_come_from_the_file_name():
    assert file_year("CORE-1999-501C3-CHARITIES-PZ.csv") == 1999
    assert file_scope("CORE-1999-501C3-CHARITIES-PZ.csv") == "501C3-CHARITIES-PZ"
