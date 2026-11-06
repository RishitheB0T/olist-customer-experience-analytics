# Power BI dashboard: how to build it (Phase 6)

Three pages: **Overview**, **Delivery deep-dive** and **Sellers**. The data comes from the
`dashboard` views in PostgreSQL ([`sql/dashboard_views.sql`](../sql/dashboard_views.sql), built by
`python -m src.pipeline`), so the dashboard needs no extra cleaning. The measures are in
[`dashboards/measures.dax`](../dashboards/measures.dax) and the colours in
[`dashboards/olist_theme.json`](../dashboards/olist_theme.json).

Each visual below lists the number it should show. If yours differs, a filter or measure is off.
Every check number comes from SQL on the same views.

## 1. Get the data (Import mode)
1. **Home > Get data > PostgreSQL database.** Server: `localhost:5432`. Database: the name in your `.env`.
   Data connectivity mode: **Import**.
2. Log in with **Database** credentials (your PostgreSQL user and password). Power BI keeps them in
   Windows, not in the `.pbix` file. If it says the connection isn't encrypted, choose **OK** (it's your own
   computer).
3. In the Navigator, tick `dashboard.orders`, `dashboard.sellers` and `analytics.dim_date` > **Load**.
4. **Home > Get data > Text/CSV** > `docs/phase5_seller_shortlist.csv` > **Load**.
5. In the **Data** pane, rename the tables to `orders`, `sellers`, `dim_date` and `shortlist`.

## 2. Model
1. **Model view:** drag to link
   - `dim_date[date_day]` → `orders[purchase_date]` (one to many)
   - `sellers[seller_id]` → `orders[seller_id]` (one to many)
   - `sellers[seller_id]` → `shortlist[seller_id]` (one to one)
2. Select `dim_date` > **Table tools > Mark as date table** > column `date_day`.
3. Add every measure from `dashboards/measures.dax` (**Modeling > New measure**, one at a time).
   Format the rates as **Percentage, 2 decimals**.
4. **View > Themes > Browse for themes** > `dashboards/olist_theme.json`.

## 3. Page 1: Overview
| Visual | Fields | Should show |
|---|---|---|
| 5 cards | Orders · Reviewed · Unhappy rate · Late rate · Unhappy value share | 99,441 · 98,673 · 14.73% · 6.77% · 17.46% |
| Line chart | X: `dim_date[month_start]`, Y: Unhappy rate. Visual filter: `dim_date[in_main_period]` = True | Jan 2017 to Aug 2018 |
| Column chart | X: `orders[days_late_band]`, Y: Unhappy rate. Visual filter: band is not blank | 9.31% · 32.18% · 67.68% · 79.36% |
| Slicer | `orders[customer_state]` (dropdown) | — |
| Text box | "Patterns in past orders, not proof of causes. Unhappy = 1-2 star review." | — |

## 4. Page 2: Delivery deep-dive
| Visual | Fields | Should show |
|---|---|---|
| Card | Avg delivery days | 12.5 |
| Column chart | X: `orders[delivery_time_band]`, Y: Unhappy rate. Visual filter: `days_late_band` = "1. on time or early" | 7.56% · 8.90% · 11.10% · 16.03% |
| Clustered bar | Y: `orders[route]`, X: Unhappy rate and Late rate | same state 11.49% / 4.56%; other state 15.08% / 8.14% |
| Table | `customer_state`, Orders, Late rate, Avg delivery days, Unhappy rate; sort by Late rate (high to low) | top row AL: 413 · 21.41% · 24.5 · 23.90% |
| Slicer | `dim_date[year]` | — |

## 5. Page 3: Sellers
| Visual | Fields | Should show |
|---|---|---|
| 4 cards | Sellers tested · Usual on-time unhappy rate · Shortlist sellers · Core sellers | 393 · 8.77% · 24 · 3 |
| Scatter chart | Values: `sellers[seller_id]`; X: Sum of `reviewed_on_time`; Y: Seller on-time unhappy rate. Visual filter: `reviewed_on_time` ≥ 50. **Analytics pane > Y-axis constant line** = 0.0877 | 393 dots; the line marks the usual rate |
| Table | `shortlist`: rank, seller_id, state, orders, rate_pct, excess, cost, benefit, chosen_share, tier. Conditional formatting (data bars) on `chosen_share` | 24 rows; top 3 = core |
| Slicer | `shortlist[tier]` | — |
| Text box | "Costs and benefits are written-down assumptions (Phase 5). A shortlist worth testing, not a promise." | — |

## 6. Save
**File > Save as** > `dashboards/olist_dashboard.pbix`. The file holds a copy of the imported data, so
check its size before committing (it must stay under 50 MB).

## Limitations
- The dashboard shows **associations**, not causes.
- **Import mode** is a snapshot: after rerunning the pipeline, press **Refresh**.
- The unhappy rate only counts reviewed orders, and the seller shortlist rests on Phase 5's assumptions.
