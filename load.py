#!/usr/bin/env python3
"""Load the LendingClub accepted-loans CSV into DuckDB and run QA checks.

Usage (from the project root):
    python3 load.py

Reads sql/01_load.sql, executes it against data/loans.duckdb, then prints
a QA summary. The raw CSV lives in data/raw/ (git-ignored); the .duckdb
file is also git-ignored — re-run this script to rebuild it.
"""
import duckdb
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB = ROOT / "data" / "loans.duckdb"
SQL = ROOT / "sql" / "01_load.sql"

con = duckdb.connect(str(DB))
con.execute(SQL.read_text())
print("Loaded tables:", [r[0] for r in con.execute("SHOW TABLES").fetchall()])

qa = {
    "total rows (loans)": "SELECT COUNT(*) FROM loans",
    "date range (issue_d)": "SELECT MIN(issue_year), MAX(issue_year) FROM loans",
    "loans with a resolved outcome (Fully Paid / Charged Off / Default)":
        "SELECT COUNT(*) FROM loans WHERE outcome IN ('Fully Paid', 'Charged Off', 'Default')",
    "loans in transitory states (excluded from default-rate denominators)":
        "SELECT COUNT(*) FROM loans WHERE outcome NOT IN ('Fully Paid', 'Charged Off', 'Default')",
    "distinct grades": "SELECT COUNT(DISTINCT grade) FROM loans",
    "distinct purposes": "SELECT COUNT(DISTINCT purpose) FROM loans",
    "null grade among resolved loans":
        "SELECT COUNT(*) FROM loans WHERE outcome IN ('Fully Paid', 'Charged Off', 'Default') AND grade IS NULL",
    "null annual_inc among resolved loans":
        "SELECT COUNT(*) FROM loans WHERE outcome IN ('Fully Paid', 'Charged Off', 'Default') AND annual_inc IS NULL",
    "null fico among resolved loans":
        "SELECT COUNT(*) FROM loans WHERE outcome IN ('Fully Paid', 'Charged Off', 'Default') AND fico IS NULL",
    "charged-off $ (funded amount lost)":
        "SELECT ROUND(SUM(loan_amnt), 0) FROM loans WHERE outcome IN ('Charged Off', 'Default')",
}
for label, q in qa.items():
    print(f"- {label}: {con.execute(q).fetchone()}")
con.close()
print("OK")
