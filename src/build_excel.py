"""Build the Excel KPI workbook (Phase 6): a summary data table + real pivot tables.

Reads the dashboard views, groups orders into one row per month x state x category x band
(about 30k rows, so the workbook stays small), then drives Excel itself through pywin32
to add the pivot tables, because Python file libraries can't create real pivot tables.
Needs Windows with Excel installed. Also adds the Phase 5 seller shortlist and an About sheet.
Usage (from the project root):  python -m src.build_excel
"""
from pathlib import Path

import pandas as pd
import win32com.client
from sqlalchemy import text
from win32com.client import gencache

from src.db import get_engine

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "excel" / "olist_kpis.xlsx"
SHORTLIST = ROOT / "docs" / "phase5_seller_shortlist.csv"

# Excel's own numbers for its settings (from Excel's documentation)
XL_ROW, XL_PAGE, XL_SUM, XL_DESC, XL_DATABASE, XL_XLSX = 1, 3, -4157, 2, 1, 51

SUMMARY_SQL = """
SELECT to_char(purchase_month, 'YYYY-MM')                AS month,
       CASE WHEN in_main_period THEN 'yes' ELSE 'no' END AS main_period,
       customer_state,
       route,
       category,
       coalesce(days_late_band, '5. not delivered')       AS days_late_band,
       coalesce(delivery_time_band, '5. not delivered')   AS delivery_time_band,
       count(*)                                           AS orders,
       count(*) FILTER (WHERE is_delivered)               AS delivered,
       count(*) FILTER (WHERE is_late AND is_delivered)   AS late,       -- late among delivered only
       count(*) FILTER (WHERE has_review)                 AS reviewed,
       count(*) FILTER (WHERE is_unhappy)                 AS unhappy,
       round(coalesce(sum(paid_total), 0), 2)::float      AS paid
FROM dashboard.orders
GROUP BY 1, 2, 3, 4, 5, 6, 7
ORDER BY 1, 3, 5
"""

# pivot sheet name -> (row field, sort by this value, page filters)
PIVOTS = {
    "By month":    ("month", None, ["main_period"]),
    "By lateness": ("days_late_band", None, ["main_period"]),
    "By state":    ("customer_state", "Total orders", ["main_period", "route"]),
    "By category": ("category", "Total orders", ["main_period", "days_late_band"]),
}


def to_rows(df: pd.DataFrame) -> list:
    """Header + rows as plain Python values (Excel can't read pandas/numpy types)."""
    body = [[None if pd.isna(v) else (v.item() if hasattr(v, "item") else v) for v in row]
            for row in df.itertuples(index=False)]
    return [list(df.columns)] + body


def write_table(sheet, df: pd.DataFrame, name: str):
    """Write a table starting at A1 in one go and turn it into a named Excel table."""
    rows = to_rows(df)
    rng = sheet.Range(sheet.Cells(1, 1), sheet.Cells(len(rows), len(rows[0])))
    rng.Value = rows
    table = sheet.ListObjects.Add(1, rng, None, 1)     # 1 = from a range, 1 = has headers
    table.Name = name
    sheet.Columns.AutoFit()
    return table


def add_pivot(wb, cache, sheet_name: str, row_field: str, sort_by, filters: list) -> None:
    """One pivot sheet: orders, reviewed, unhappy rate and late rate per row_field."""
    sheet = wb.Worksheets.Add(After=wb.Worksheets(wb.Worksheets.Count))
    sheet.Name = sheet_name
    sheet.Range("A1").Value = f"{sheet_name}: unhappy rate = unhappy ÷ reviewed; late rate = late ÷ delivered"
    pt = cache.CreatePivotTable(TableDestination=sheet.Range("A4"), TableName=f"pt_{row_field}")
    pt.AddFields(RowFields=row_field, PageFields=filters)       # rows + drop-down filters above the table
    pt.DisplayErrorString, pt.ErrorString = True, "—"            # e.g. late rate when nothing was delivered
    existing = {f.Name for f in pt.CalculatedFields()}         # shared by all pivots on one cache
    if "unhappy_rate" not in existing:
        pt.CalculatedFields().Add("unhappy_rate", "=unhappy/reviewed", True)
        pt.CalculatedFields().Add("late_rate", "=late/delivered", True)
    for field, caption, fmt in [("orders", "Total orders", "#,##0"), ("reviewed", "Total reviewed", "#,##0"),
                                ("unhappy_rate", "Unhappy rate", "0.00%"), ("late_rate", "Late rate", "0.00%")]:
        pt.AddDataField(pt.PivotFields(field), caption, XL_SUM).NumberFormat = fmt
    if sort_by:
        pt.PivotFields(row_field).AutoSort(XL_DESC, sort_by)    # biggest groups first
    sheet.Columns.AutoFit()


def main() -> None:
    with get_engine().connect() as conn:
        summary = pd.read_sql(text(SUMMARY_SQL), conn)
    shortlist = pd.read_csv(SHORTLIST)
    print(f"summary rows: {len(summary):,} | orders: {summary['orders'].sum():,} | "
          f"shortlist sellers: {len(shortlist)}")

    OUT.parent.mkdir(exist_ok=True)
    # DispatchEx: a separate, hidden Excel (never touches one you have open).
    # EnsureDispatch wraps it with Excel's full command list, so named arguments like After= work.
    excel = gencache.EnsureDispatch(win32com.client.DispatchEx("Excel.Application"))
    excel.Visible, excel.DisplayAlerts = False, False
    try:
        wb = excel.Workbooks.Add()
        about = wb.Worksheets(1)
        about.Name = "About"
        data = wb.Worksheets.Add(After=about)
        data.Name = "Data"
        write_table(data, summary, "OrdersSummary")
        cache = wb.PivotCaches().Create(SourceType=XL_DATABASE, SourceData="OrdersSummary")
        for name, (row_field, sort_by, filters) in PIVOTS.items():
            add_pivot(wb, cache, name, row_field, sort_by, filters)
        sellers = wb.Worksheets.Add(After=wb.Worksheets(wb.Worksheets.Count))
        sellers.Name = "Seller shortlist"
        write_table(sellers, shortlist, "SellerShortlist")
        write_about(about)
        about.Activate()
        wb.SaveAs(str(OUT), FileFormat=XL_XLSX)
        wb.Close(False)
    finally:
        excel.Quit()                                             # never leave a hidden Excel running
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size / 1e6:.1f} MB)")


def write_about(sheet) -> None:
    """Plain notes for whoever opens the workbook."""
    lines = [
        "Olist customer experience: KPI workbook (built by src/build_excel.py)",
        "",
        "Sheets",
        "Data: orders grouped by month, customer state, route, category and delivery bands (one row per group).",
        "By month / By lateness / By state / By category: pivot tables. Use the filters above each table.",
        "Seller shortlist: the Phase 5 ranked sellers worth testing (assumption-based; see docs/phase5_seller_prioritisation.md).",
        "",
        "KPIs",
        "Unhappy rate = orders with a 1-2 star review ÷ reviewed orders.",
        "Late rate = orders delivered after the promised date ÷ delivered orders.",
        "Main period = Jan 2017 to Aug 2018 (months outside it have very few orders).",
        "Category is the product's category when the order has one product, else 'several products'.",
        "",
        "Limitations",
        "These are patterns in past orders (things that go together), not proof of causes.",
        "Orders without a review are left out of the unhappy rate.",
        "Seller shortlist costs and benefits are written-down assumptions, not data.",
    ]
    sheet.Range(sheet.Cells(1, 1), sheet.Cells(len(lines), 1)).Value = [[line] for line in lines]
    sheet.Range("A1").Font.Bold = True
    sheet.Range("A1").Font.Size = 14
    for row in (3, 8, 14):
        sheet.Cells(row, 1).Font.Bold = True


if __name__ == "__main__":  # run main() only when this file is run directly
    main()
