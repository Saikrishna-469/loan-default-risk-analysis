#!/usr/bin/env python3
"""Build the EDA notebook (notebooks/01_eda.ipynb) and the charts in images/.

Usage (from the project root):
    python3 notebooks/build_notebook.py

Reads data/loans.duckdb (built by load.py), reproduces the headline charts
with matplotlib/seaborn, fits the stretch logistic-regression model on
application-time features only (no grade, no post-origination fields), and
writes the notebook with the charts embedded as cell outputs.
"""
import base64
import io

import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import nbformat as nbf
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "loans.duckdb"
IMG = ROOT / "images"
IMG.mkdir(exist_ok=True)

plt.rcParams.update({"figure.figsize": (10, 5.5), "font.size": 11})
NAVY = "#1f3a5f"
TEAL = "#2a9d8f"
RUST = "#c0392b"

con = duckdb.connect(str(DB), read_only=True)
resolved = con.execute("SELECT * FROM resolved").fetchdf()
print(f"resolved loans: {len(resolved):,}")

charts = {}  # name -> (png bytes, caption)


def save_chart(name, fig, caption):
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=150, bbox_inches="tight")
    plt.close(fig)
    charts[name] = (buf.getvalue(), caption)
    (IMG / f"{name}.png").write_bytes(buf.getvalue())
    print(f"chart: {name}.png")


# 1. Default rate by grade (+ average interest rate on a second axis)
g = con.execute("""
    SELECT grade, ROUND(100.0*AVG(defaulted),2) AS default_rate_pct,
           ROUND(AVG(int_rate),2) AS avg_int_rate_pct
    FROM resolved GROUP BY grade ORDER BY grade
""").fetchdf()
fig, ax = plt.subplots()
bars = ax.bar(g["grade"], g["default_rate_pct"], color=RUST, width=0.6)
ax.set_ylabel("Default rate (%)")
ax.set_xlabel("LendingClub grade")
ax.set_title("Default rate rises 8x from grade A (6.0%) to grade G (49.9%)")
for b, v in zip(bars, g["default_rate_pct"]):
    ax.text(b.get_x() + b.get_width() / 2, v + 1, f"{v:.1f}%", ha="center")
ax2 = ax.twinx()
ax2.plot(g["grade"], g["avg_int_rate_pct"], color=NAVY, marker="o", lw=2)
ax2.set_ylabel("Average interest rate (%)", color=NAVY)
ax2.tick_params(axis="y", labelcolor=NAVY)
ax.set_ylim(0, 58)
save_chart("default_rate_by_grade", fig,
           "Default rate by grade with the average interest rate charged (line).")

# 2. FICO x DTI heatmap
h = con.execute("""
    SELECT fico_band, dti_band, ROUND(100.0*AVG(defaulted),2) AS default_rate_pct
    FROM resolved GROUP BY fico_band, dti_band
""").fetchdf()
piv = h.pivot(index="fico_band", columns="dti_band", values="default_rate_pct")
order_rows = ["650-699", "700-749", "750-799", "800+"]
order_cols = ["<10", "10-15", "15-20", "20-25", "25-30", "30+"]
piv = piv.reindex(index=order_rows, columns=order_cols)
fig, ax = plt.subplots(figsize=(10, 5))
sns.heatmap(piv, annot=True, fmt=".1f", cmap="Reds", ax=ax,
            cbar_kws={"label": "Default rate (%)"})
ax.set_title("Default rate by FICO band x debt-to-income band")
ax.set_xlabel("Debt-to-income (DTI)")
ax.set_ylabel("FICO band")
save_chart("fico_x_dti_heatmap", fig,
           "Default rate (%) by FICO band and DTI band. Only 2 resolved loans had FICO <650 — approved loans start at ~660.")

# 3. Default rate by purpose (horizontal, sorted)
p = con.execute("""
    SELECT purpose, ROUND(100.0*AVG(defaulted),2) AS default_rate_pct,
           COUNT(*) AS n
    FROM resolved GROUP BY purpose ORDER BY default_rate_pct
""").fetchdf()
fig, ax = plt.subplots(figsize=(10, 6))
ax.barh(p["purpose"], p["default_rate_pct"], color=TEAL)
ax.set_xlabel("Default rate (%)")
ax.set_title("Default rate by loan purpose (resolved loans)")
for i, (v, n) in enumerate(zip(p["default_rate_pct"], p["n"])):
    ax.text(v + 0.4, i, f"{v:.1f}%  (n={n:,})", va="center")
ax.set_xlim(0, 38)
save_chart("default_rate_by_purpose", fig,
           "Default rate by stated loan purpose, with loan counts.")

# 4. Default rate by issue year
y = con.execute("""
    SELECT issue_year, ROUND(100.0*AVG(defaulted),2) AS default_rate_pct,
           COUNT(*) AS n FROM resolved GROUP BY issue_year ORDER BY issue_year
""").fetchdf()
fig, ax = plt.subplots()
ax.plot(y["issue_year"], y["default_rate_pct"], color=NAVY, marker="o", lw=2)
ax.set_ylabel("Default rate (%)")
ax.set_xlabel("Issue year")
ax.set_title("Default rate by issue year (resolved loans only)")
ax.set_ylim(0, 28)
for x, v in zip(y["issue_year"], y["default_rate_pct"]):
    ax.annotate(f"{v:.1f}%", (x, v), textcoords="offset points",
                xytext=(0, 8), ha="center", fontsize=9)
save_chart("default_rate_by_year", fig,
           "Default rate by issue year. 2017-2018 look lower partly because most of those loans are still Current and excluded.")

# 5. Term effect within grade: 36 vs 60 months
t = con.execute("""
    SELECT grade, term_months, ROUND(100.0*AVG(defaulted),2) AS default_rate_pct
    FROM resolved GROUP BY grade, term_months ORDER BY grade, term_months
""").fetchdf()
piv = t.pivot(index="grade", columns="term_months", values="default_rate_pct")
fig, ax = plt.subplots()
x = np.arange(len(piv.index))
w = 0.38
ax.bar(x - w / 2, piv[36], w, label="36 months", color=TEAL)
ax.bar(x + w / 2, piv[60], w, label="60 months", color=RUST)
ax.set_xticks(x)
ax.set_xticklabels(piv.index)
ax.set_ylabel("Default rate (%)")
ax.set_xlabel("Grade")
ax.set_title("60-month loans default far more than 36-month loans, at every grade")
ax.legend()
for xi, v in zip(x - w / 2, piv[36]):
    ax.text(xi, v + 1, f"{v:.0f}%", ha="center", fontsize=9)
for xi, v in zip(x + w / 2, piv[60]):
    ax.text(xi, v + 1, f"{v:.0f}%", ha="center", fontsize=9)
ax.set_ylim(0, 60)
save_chart("default_rate_by_term_grade", fig,
           "Default rate by grade and term: 60-month loans default at roughly double the 36-month rate in every grade.")

# 6. Net principal lost by grade ($)
loss = con.execute("""
    SELECT grade,
           ROUND(SUM(loan_amnt - total_rec_prncp) FILTER (WHERE defaulted=1)/1e6,1) AS net_lost_m
    FROM resolved GROUP BY grade ORDER BY grade
""").fetchdf()
fig, ax = plt.subplots()
bars = ax.bar(loss["grade"], loss["net_lost_m"], color=NAVY, width=0.6)
ax.set_ylabel("Net principal lost ($m)")
ax.set_xlabel("Grade")
ax.set_title("Net principal lost to defaults by grade ($m, resolved loans)")
for b, v in zip(bars, loss["net_lost_m"]):
    ax.text(b.get_x() + b.get_width() / 2, v + 12, f"${v:,.0f}m", ha="center")
ax.set_ylim(0, 1050)
save_chart("net_loss_by_grade", fig,
           "Net principal lost (funded $ minus principal recovered) on defaulted loans, by grade.")

# ---- Stretch model: logistic regression on APPLICATION-TIME features only ----
# Grade / sub-grade / interest rate are the lender's own post-application
# assessment, so they are excluded — a granting model must decide before they exist.
# Post-origination fields (total payments, recoveries, outstanding principal)
# would leak the outcome and are also excluded.
model_df = resolved[
    ["fico", "dti", "annual_inc", "emp_length_years", "loan_amnt",
     "term_months", "home_ownership", "purpose", "verification_status",
     "defaulted"]
].copy()
model_df = model_df.dropna(subset=["fico", "dti", "annual_inc", "loan_amnt",
                                   "term_months", "emp_length_years"])
model_df["log_income"] = np.log(model_df["annual_inc"])
model_df["log_loan_amnt"] = np.log(model_df["loan_amnt"])
model_df = pd.get_dummies(
    model_df,
    columns=["home_ownership", "purpose", "verification_status"],
    drop_first=True, dtype=float)
X = model_df.drop(columns=["defaulted", "annual_inc", "loan_amnt"])
y = model_df["defaulted"]
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y)
scaler = StandardScaler()
X_train_s = scaler.fit_transform(X_train)
X_test_s = scaler.transform(X_test)
clf = LogisticRegression(max_iter=1000, class_weight="balanced")
clf.fit(X_train_s, y_train)
auc = roc_auc_score(y_test, clf.predict_proba(X_test_s)[:, 1])
print(f"logistic regression ROC-AUC (application-time features only): {auc:.3f}")
odds = pd.Series(np.exp(clf.coef_[0]), index=X.columns).sort_values(ascending=False)
print("top odds ratios (per 1 SD for numeric features):")
print(odds.head(8).round(3).to_string())
print("bottom odds ratios:")
print(odds.tail(5).round(3).to_string())
(ROOT / "notebooks" / "model_results.txt").write_text(
    f"ROC-AUC: {auc:.3f}\n\nTop odds ratios (per 1 SD for numeric features):\n"
    f"{odds.head(8).round(3).to_string()}\n\nLowest odds ratios:\n"
    f"{odds.tail(5).round(3).to_string()}\n")

# ---- Build the notebook ----
nb = nbf.v4.new_notebook()
nb.metadata = {"kernelspec": {"display_name": "Python 3", "language": "python",
                              "name": "python3"}}
cells = []
cells.append(nbf.v4.new_markdown_cell(
    "# Loan Default Risk Analysis — EDA\n\n"
    "**Business question:** which LendingClub loan applications should a lender "
    "approve, at what grade / rate / amount / term — and which should it decline "
    "or price higher?\n\n"
    "Data: LendingClub accepted loans, 2007–2018Q4 (Kaggle). "
    "Default = Charged Off / Default; Fully Paid = repaid. Loans still Current, "
    "Late or In Grace Period are excluded from default-rate denominators "
    "because their outcome is not known yet."))
cells.append(nbf.v4.new_code_cell(
    "import duckdb\ncon = duckdb.connect('data/loans.duckdb', read_only=True)\n"
    "print(con.execute(\"SELECT COUNT(*) FROM resolved\").fetchone())  # resolved loans"))

for name, (png, caption) in charts.items():
    title = caption.split(".")[0]
    cells.append(nbf.v4.new_markdown_cell(f"## {title}\n\n{caption}"))
    cell = nbf.v4.new_code_cell(
        f"# see sql/ for the query behind this chart\n"
        f"from IPython.display import Image\nImage('images/{name}.png')")
    cell.outputs = [nbf.v4.new_output(
        "display_data",
        data={"image/png": base64.b64encode(png).decode()},
        metadata={"image/png": {"width": 900}})]
    cells.append(cell)

cells.append(nbf.v4.new_markdown_cell(
    "## Stretch model — logistic regression (application-time features only)\n\n"
    f"ROC-AUC on a held-out 20% test set: **{auc:.3f}**. "
    "Grade, sub-grade and interest rate are deliberately excluded: they are the "
    "lender's own post-application assessment, so a granting model cannot use "
    "them. Post-origination fields (payments received, recoveries) would leak "
    "the outcome. Full odds ratios are in `notebooks/model_results.txt`."))
cells.append(nbf.v4.new_code_cell(
    "# Model code lives in notebooks/build_notebook.py (reproducible end to end).\n"
    "# Features: fico, dti, log(annual_inc), emp_length_years, log(loan_amnt),\n"
    "# term_months + dummies for home_ownership, purpose, verification_status.\n"
    "# LogisticRegression(class_weight='balanced'), 80/20 stratified split."))
nb.cells = cells
nbf.write(nb, ROOT / "notebooks" / "01_eda.ipynb")
print(f"notebook written with {len(cells)} cells; model ROC-AUC {auc:.3f}")
con.close()
