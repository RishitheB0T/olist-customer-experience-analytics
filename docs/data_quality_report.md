# Data quality report

What we found in the Olist data, and the rule we used for each problem. This report covers
Phase 2 (raw → clean → analytics); the question and KPIs are in [problem_brief.md](problem_brief.md).

**Main principle: nothing is deleted.** Odd rows stay in the tables with a `flag_...` column
(true = this row has the problem), so each analysis decides what to leave out and says so.
The only data left out of a table is map points that are copies of other points or that fall outside Brazil (section 3.5).

**Every number below comes from saved code.** To reproduce them:

```powershell
.\.venv\Scripts\python.exe -m src.pipeline                          # rebuild everything + run the tests
.\.venv\Scripts\python.exe -m src.run_sql sql/report_data_quality.sql  # numbers the check files don't print
```

The other numbers come from `sql/profile_*.sql` (raw layer) and `sql/check_*.sql` (each built table).

## 1. Data received

9 CSV files from Kaggle (`olistbr/brazilian-ecommerce`), loaded as text into schema `raw`.
Every table's row count matched its file.

| File (table) | Rows |
|---|---|
| orders | 99,441 |
| customers | 99,441 |
| order_items | 112,650 |
| order_payments | 103,886 |
| order_reviews | 99,224 |
| products | 32,951 |
| sellers | 3,095 |
| geolocation | 1,000,163 |
| product_category_name_translation | 71 |

## 2. Unique IDs and links

- Every ID is unique except `review_id` (814 extra rows). `review_id + order_id` is unique, so that pair is the key.
- 99,441 `customer_id`s belong to 96,096 people (`customer_unique_id`): Olist gives every order a new
  customer_id. Repeat purchases (P5) must use `customer_unique_id`.
- No item, payment or review points at an order that doesn't exist. The links that do break are covered below
  (zip codes with no map point, untranslated categories, 1 order with no payment).

## 3. Problems found and how each was handled

### 3.1 Orders

| Problem | Count | What we did |
|---|---|---|
| Months at the edges are almost empty (Sep 2016: 4, Oct 2016: 324, Nov 2016: none, Dec 2016: 1, Sep 2018: 16, Oct 2018: 4) | 349 orders outside Jan 2017 – Aug 2018 | `in_main_period` flag; trends use the 99,092 orders inside |
| Status "delivered" but no delivery date | 8 | `flag_delivered_without_date` |
| Delivery date but status not "delivered" (all canceled) | 6 | `flag_delivery_date_not_delivered` |
| Handed to the carrier before the purchase time | 166 | `flag_handover_before_purchase`. Counted in calendar days only 2 are negative: most happen on the same day |
| Delivered before it was handed to the carrier | 23 | `flag_delivered_before_handover`. In calendar days, 20 are negative |
| Orders with no items (603 unavailable, 164 canceled, 5 created, 2 invoiced, 1 shipped) | 775 | kept; `n_items = 0` |
| Order with no payment rows | 1 | kept; `paid_total` is empty |

### 3.2 Products and categories

| Problem | Count | What we did |
|---|---|---|
| No category (these also have no name, description or photo info) | 610 products | English category `unknown`; `flag_no_category` |
| Category missing from Olist's translation list (2 categories) | 13 products | translated by this project, marked `translated_by = 'this project'` (73 categories, 74 English names with `unknown`) |
| Weight 0 g | 4 | `flag_zero_weight` |
| Missing size | 2 | `flag_missing_size`; their volume is empty |
| Misspelled columns `..._lenght` | 2 columns | renamed to `..._length` |

### 3.3 Items, payments and money

| Problem | Count | What we did |
|---|---|---|
| Delivery fee of 0 | 383 items | `flag_zero_freight` (may be free delivery) |
| Odd payment rows: value 0 (9), 0 instalments (2), type `not_defined` (3); some rows have two of these | 11 rows | `flag_odd_payment` |
| Amount paid differs from items + delivery fees by more than 1 BRL | 249 of 98,665 orders (232 paid more, 17 paid less) | **order value = amount paid** (`paid_total`); items + fees kept as `items_total`; `flag_paid_mismatch` |
| Items in one order with different hand-over deadlines | 325 orders with 2, 11 with 3 (98,330 have one) | order-level "handed over late?" only for one-deadline orders; every item is checked against its own deadline in `fact_order_item` |
| Deadline far after purchase (median: 6 days). 7 orders at 69-148 days, 3 at 1,052-1,056 days (deadlines in 2020) | 12 items in 10 orders | `flag_odd_deadline` (more than 60 days) |
| Items never handed to a carrier | 1,194 | "handed over late?" left empty |

Of the 232 orders that paid more, 98.7% paid in instalments, against 51.5% of all orders. So paying more is
linked with paying in instalments, which may be an instalment charge. The data doesn't say, so this is not confirmed.

### 3.4 Reviews

| Problem | Count | What we did |
|---|---|---|
| Orders with no review | 768 | `has_review = false`; `is_unhappy` is empty, so they are left out of rating comparisons |
| Orders with 2 or 3 reviews (543 + 4) | 547 | **one review per order: the lowest score** (the project studies unhappy customers). Ties (346 orders): the latest answer, then `review_id` |
| One `review_id` used on several orders (always the same person and the same score) | 789 IDs on 1,603 rows | key = `review_id + order_id`; `flag_review_id_shared` |
| Survey sent on an earlier day than the order arrived | 5,127 reviews | `flag_survey_before_delivery` |
| Answered 30 or more days after the survey was sent (472 at 30-89 days, 210 at 90+) | 682 | kept; `answer_delay_days` lets an analysis leave them out |
| Survey date has a time, not just a date | 85 | kept as a timestamp |
| Missing comment title / message | 88.34% / 58.70% | `has_comment` (40,977 reviews have a message) |

**How much the lowest-score rule matters:** in the 547 multi-review orders, the scores differ in 202.
The lowest score counts 137 of them as unhappy, while the latest review would count 98. That is 39 orders
out of 98,673 reviewed orders.

### 3.5 Locations (geolocation)

| Problem | Count | What we did |
|---|---|---|
| Many points per zip prefix (about 52.6) | 1,000,163 rows, 19,015 prefixes | **one point per prefix = the median of its distinct points inside Brazil** (720,154 distinct points, 720,121 used) |
| Points outside Brazil | 42 rows in 21 prefixes | left out of the median; 5 prefixes had only such points, so they get no location (19,010 prefixes kept) |
| Points of one prefix name more than one state | 8 prefixes | the median follows most of the points; the spread shows how scattered they are |
| Points far from their prefix's centre | 428 prefixes over 50 km, 88 over 500 km (median spread 1.5 km) | `spread_km` kept, so analyses can skip vague locations |
| Prefix has a single point (precision unknown) | 1,233 prefixes | spread shows 0; treat with care |
| Customer or seller with no map point | 279 customers (158 prefixes), 7 sellers | map point empty; distance empty |

Seller-to-customer distance (straight line) is filled for 96,904 single-seller orders: median 433.9 km,
longest 3,579.3 km.

## 4. The analytics tables (star schema)

| Table | One row per | Rows |
|---|---|---|
| `dim_customer` | customer_id (= one per order) | 99,441 |
| `dim_seller` | seller | 3,095 |
| `dim_product` | product | 32,951 |
| `dim_date` | day, whole years 2016-2018 (608 days in the main period) | 1,096 |
| `fact_order` | order | 99,441 |
| `fact_order_item` | item in an order | 112,650 |

Every day count (delivery, promised, late, seller and carrier parts) uses calendar days, not hours.

## 5. Proof that nothing was lost or double-counted

- **Row counts** are equal from raw to clean to analytics for every table above.
- **Money totals** are identical in raw and analytics: payments 16,008,872.12, item prices 13,591,643.70,
  delivery fees 2,251,909.54.
- **13 automated tests** (`tests/data_quality.sql`, run by `python -m src.run_tests`) all pass. They cover layers,
  reviews, dates, delivery, locations, items, recorded counts and the unhappy flag.
- **All-or-nothing build:** the 8 SQL builds run in one transaction. In a test, a deliberate failure after dropping
  a table left every table and rule exactly as before.

## 6. Limitations

1. **Flags are not fixes.** Flagged rows are still in the tables. Each analysis must choose whether to leave
   them out, and say how many it left out.
2. **The rules are choices.** Lowest score, the 60-day deadline limit, the 1 BRL tolerance and Brazil's
   rough box are reasonable, but other reasonable choices would move some numbers slightly (for example 39
   unhappy orders for the review rule).
3. **We can't check with Olist.** Whether the 2020 deadlines are typing errors, or what the extra amount paid is,
   can't be confirmed from this data.
4. **Locations are approximate.** A zip prefix covers an area, 1,233 prefixes have a single point, and distances are
   straight lines, not roads.
5. **The "known counts" test is tied to this version of the dataset.** A new download would need its expected
   numbers updated.
6. **The raw load is not part of the all-or-nothing build.** If loading a CSV fails halfway, rerun the pipeline.
