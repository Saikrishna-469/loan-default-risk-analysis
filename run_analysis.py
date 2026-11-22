#!/usr/bin/env python3
"""Run every analysis in sql/ and save dashboard-ready CSVs.

Usage (from the project root):
    python3 run_analysis.py

Executes sql/02_metrics.sql .. sql/07_concentration.sql against
data/loans.duckdb. Each query result is printed and saved to
dashboard/<sqlfile>_q<N>.csv. Re-run any time after load.py.
"""
import re
import duckdb
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB = ROOT / "data" / "loans.duckdb"
SQL_DIR = ROOT / "sql"
OUT_DIR = ROOT / "dashboard"
OUT_DIR.mkdir(exist_ok=True)

con = duckdb.connect(str(DB), read_only=True)

for sql_file in sorted(SQL_DIR.glob("0[2-7]_*.sql")):
    text = sql_file.read_text()
    # strip -- comments, then split on semicolons
    text = re.sub(r"--[^\n]*", "", text)
    statements = [s.strip() for s in text.split(";") if s.strip()]
    for i, stmt in enumerate(statements, 1):
        if not stmt.upper().startswith(("SELECT", "WITH")):
            continue
        name = f"{sql_file.stem}_q{i}"
        df = con.execute(stmt).fetchdf()
        df.to_csv(OUT_DIR / f"{name}.csv", index=False)
        print(f"\n===== {name} ({len(df)} rows) =====")
        print(df.to_string(index=False))
con.close()
print("\nAll query outputs saved to dashboard/*.csv")
