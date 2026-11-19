-- Check numbers for the Power BI dashboard (Phase 6): every "Should show" value in
-- docs/dashboard_guide.md, worked out straight from the dashboard views.
-- Each query uses the same rule as the matching Power BI measure in dashboards/measures.dax.
-- (Shortlist sellers = 24 and Core sellers = 3 come from docs/phase5_seller_shortlist.csv,
--  which is not in the database; Power BI reads that file directly.)
-- Run with:  python -m src.run_sql sql/check_dashboard.sql

-- name: Page 1 - cards (Orders, Reviewed, Unhappy rate, Late rate, Unhappy value share)
SELECT count(*)                                                     AS orders,
       count(*) FILTER (WHERE has_review)                           AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy)
                   / count(*) FILTER (WHERE has_review), 2)         AS unhappy_rate_pct,
       round(100.0 * count(*) FILTER (WHERE is_late AND is_delivered)
                   / count(*) FILTER (WHERE is_delivered), 2)       AS late_rate_pct,
       round(100.0 * sum(paid_total) FILTER (WHERE is_unhappy)
                   / sum(paid_total) FILTER (WHERE has_review), 2)  AS unhappy_value_share_pct
FROM dashboard.orders;

-- name: Page 1 - line chart: unhappy rate by month (main period only, Jan 2017 - Aug 2018)
SELECT to_char(d.month_start, 'YYYY-MM')                            AS month,
       count(*) FILTER (WHERE o.has_review)                         AS reviewed,
       round(100.0 * count(*) FILTER (WHERE o.is_unhappy)
                   / nullif(count(*) FILTER (WHERE o.has_review), 0), 2) AS unhappy_rate_pct
FROM dashboard.orders o
JOIN analytics.dim_date d ON d.date_day = o.purchase_date
WHERE d.in_main_period
GROUP BY d.month_start
ORDER BY d.month_start;

-- name: Page 1 - column chart: unhappy rate by days-late band (blank band left out)
SELECT days_late_band,
       count(*) FILTER (WHERE has_review)                           AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy)
                   / count(*) FILTER (WHERE has_review), 2)         AS unhappy_rate_pct
FROM dashboard.orders
WHERE days_late_band IS NOT NULL
GROUP BY days_late_band
ORDER BY days_late_band;

-- name: Page 2 - card: average delivery days (delivered orders)
SELECT round(avg(delivery_days) FILTER (WHERE is_delivered), 2)     AS avg_delivery_days
FROM dashboard.orders;

-- name: Page 2 - column chart: unhappy rate by delivery time (on-time orders only)
SELECT delivery_time_band,
       count(*) FILTER (WHERE has_review)                           AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy)
                   / count(*) FILTER (WHERE has_review), 2)         AS unhappy_rate_pct
FROM dashboard.orders
WHERE days_late_band = '1. on time or early'
GROUP BY delivery_time_band
ORDER BY delivery_time_band;

-- name: Page 2 - clustered bar: unhappy rate and late rate by route
SELECT route,
       round(100.0 * count(*) FILTER (WHERE is_unhappy)
                   / nullif(count(*) FILTER (WHERE has_review), 0), 2)  AS unhappy_rate_pct,
       round(100.0 * count(*) FILTER (WHERE is_late AND is_delivered)
                   / nullif(count(*) FILTER (WHERE is_delivered), 0), 2) AS late_rate_pct
FROM dashboard.orders
GROUP BY route
ORDER BY route;

-- name: Page 2 - table: top 3 customer states by late rate
SELECT customer_state,
       count(*)                                                     AS orders,
       round(100.0 * count(*) FILTER (WHERE is_late AND is_delivered)
                   / count(*) FILTER (WHERE is_delivered), 2)       AS late_rate_pct,
       round(avg(delivery_days) FILTER (WHERE is_delivered), 1)     AS avg_delivery_days,
       round(100.0 * count(*) FILTER (WHERE is_unhappy)
                   / count(*) FILTER (WHERE has_review), 2)         AS unhappy_rate_pct
FROM dashboard.orders
GROUP BY customer_state
ORDER BY late_rate_pct DESC
LIMIT 3;

-- name: Page 3 - cards: sellers tested (50+ on-time reviewed orders) and the usual on-time unhappy rate
SELECT count(*) FILTER (WHERE reviewed_on_time >= 50)               AS sellers_tested,
       round(100.0 * sum(unhappy_on_time) / sum(reviewed_on_time), 2) AS usual_on_time_unhappy_rate_pct,
       round(sum(unhappy_on_time)::numeric / sum(reviewed_on_time), 4) AS constant_line_value
FROM dashboard.sellers;
