# Power BI dashboard: how to build it (Phase 6)

Three pages: **Overview**, **Delivery deep-dive** and **Sellers**. The data comes from the
`dashboard` views in PostgreSQL ([`sql/dashboard_views.sql`](../sql/dashboard_views.sql), built by
`python -m src.pipeline`), so the dashboard needs no extra cleaning. The measures are in
[`dashboards/measures.dax`](../dashboards/measures.dax) and the colours in
[`dashboards/olist_theme.json`](../dashboards/olist_theme.json).

Each visual below lists the number it should show. If yours differs, a filter or measure is off.
Every check number comes from SQL on the same views: run
`python -m src.run_sql sql/check_dashboard.sql` to see them.

## 1. Get the data (Import mode)
1. **Home > Get data > PostgreSQL database.** Server: `localhost:5432`. Database: the name in your `.env`.
   Data connectivity mode: **Import**.
2. Log in with your PostgreSQL user and password (newer versions: **Authentication kind: Basic** on the
   same page; Privacy level **Private**). Power BI keeps them in
   Windows, not in the `.pbix` file. If it says the connection isn't encrypted, choose **OK** (it's your own
   computer).
3. In the Navigator, tick `dashboard.orders`, `dashboard.sellers` and `analytics.dim_date` > **Load**.
4. **Home > Get data > Text/CSV** > `docs/phase5_seller_shortlist.csv` > **Load**.
5. In the **Data** pane, rename the tables to `orders`, `sellers`, `dim_date` and `shortlist`
   (the measures use these names). Row counts: 99,441 · 3,078 · 1,096 · 24.

## 2. Model
1. **Home > Manage relationships** (Power BI may have added some by itself): keep exactly these 3
   - `dim_date[date_day]` → `orders[purchase_date]` (one to many, single direction)
   - `sellers[seller_id]` → `orders[seller_id]` (one to many, single direction)
   - `sellers[seller_id]` → `shortlist[seller_id]` (one to one, both directions)
2. Select `dim_date` > **Table tools > Mark as date table** > column `date_day`.
3. Add all 15 measures from `dashboards/measures.dax` (**Home > New measure**, one at a time, in file
   order): the first 10 in `orders`, the 3 seller ones in `sellers`, the 2 shortlist ones in `shortlist`.
   Format the 5 rates as **Percentage, 2 decimals** and Avg delivery days with **1 decimal**.
4. **Design > Import theme** (older versions: **View > Themes > Browse for themes**) > `dashboards/olist_theme.json`.

**Number cards:** cards round big numbers to "99K" by default. Click the card > **Format visual >
Callout value**, set **Apply settings to** to the measure (Display units is hidden while it says *All*),
then **Display units: None** and turn the thousands separator on.

## 3. Page 1: Overview
| Visual | Fields | Should show |
|---|---|---|
| 5 cards | Orders · Reviewed · Unhappy rate · Late rate · Unhappy value share | 99,441 · 98,673 · 14.73% · 6.77% · 17.46% |
| Line chart | X: `dim_date[month_start]`, Y: Unhappy rate. Visual filter: `dim_date[in_main_period]` = True | 20 points: Jan 2017 15.57%, Mar 2018 22.80% (highest), Aug 2018 10.93% |
| Column chart | X: `orders[days_late_band]`, Y: Unhappy rate. Visual filter: band is not blank | 9.31% · 32.18% · 67.68% · 79.36% |
| Slicer | `orders[customer_state]` (dropdown) | pick SP: Unhappy rate card = 12.66% |
| Text box | "Patterns in past orders, not proof of causes. Unhappy = 1-2 star review." | — |

## 4. Page 2: Delivery deep-dive
| Visual | Fields | Should show |
|---|---|---|
| Card | Avg delivery days | 12.5 |
| Column chart | X: `orders[delivery_time_band]`, Y: Unhappy rate. Visual filter: `days_late_band` = "1. on time or early" | 7.56% · 8.90% · 11.10% · 16.03% |
| Clustered bar | Y: `orders[route]`, X: Unhappy rate and Late rate. Visual filter: route = same state, other state ("several sellers" and "no items" have no single seller location) | same state 11.49% / 4.56%; other state 15.08% / 8.14% |
| Table | `customer_state`, Orders, Late rate, Avg delivery days, Unhappy rate; sort by Late rate (high to low). Title: "Customer states, highest late rate first" | top row AL: 413 · 21.41% · 24.5 · 23.90% |
| Slicer | `dim_date[year]`, style **Tile** | pick 2018: Avg delivery days = 12.1 (2017: 13.0) |

## 5. Page 3: Sellers
| Visual | Fields | Should show |
|---|---|---|
| 4 cards | Sellers tested · Usual on-time unhappy rate · Shortlist sellers · Core sellers | 393 · 8.77% · 24 · 3 |
| Scatter chart | Values: `sellers[seller_id]`; X: `reviewed_on_time` set to **Sum** ("Don't summarize" gives an error); Y: Seller on-time unhappy rate. Visual filter: Sum of `reviewed_on_time` ≥ 50 (advanced filtering). **Analytics pane > Y-axis constant line**, value from the **fx** button = Usual on-time unhappy rate | 393 dots; highest dot = seller 1ca7077d…, 87 orders, 54.02% |
| Table | `shortlist`: rank, seller_id, state, orders, rate_pct, excess, cost, benefit, chosen_share, tier. Totals off; sort by rank; data bars on `chosen_share`. Needs about half the page width to show every column | 24 rows; top 3 = core (2eb70248, 1ca7077d, 7c67e144) |
| Slicer | `shortlist[tier]`, style **Tile**. Visual filter: tier **is not blank** (the 1:1 link adds a blank row for the 3,054 sellers not in the shortlist) | pick core: Shortlist sellers 3, Sellers tested 3, Usual stays 8.77% |
| Text box | "Costs and benefits are written-down assumptions (Phase 5). A shortlist worth testing, not a promise." | — |

## 6. Save and export
1. **File > Save as** > `dashboards/olist_dashboard.pbix`. The file holds a copy of the imported data, so
   check its size before committing (it must stay under 50 MB; ours is 4.3 MB).
2. **File > Export > Export to PDF** > `dashboards/olist_dashboard.pdf` (one page per report page).
3. One PNG per page in `dashboards/screenshots/` (`overview.png`, `delivery.png`, `sellers.png`). A PDF
   page converted to PNG gives a clean image with no desktop in it.

## Limitations
- The dashboard shows **associations**, not causes.
- **Import mode** is a snapshot: after rerunning the pipeline, press **Refresh**.
- The unhappy rate only counts reviewed orders, and the seller shortlist rests on Phase 5's assumptions.
- The PDF and screenshots are static: the state table on page 2 scrolls in Power BI, so only its top rows show.
