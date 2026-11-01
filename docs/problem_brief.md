# Problem Brief — Olist Customer Experience

## 1. The business question

**Main question:**
> What is linked with unhappy customers on Olist, and which of those things
> would be worth testing a fix for first?

**Who is asking:** Olist's customer experience team (an imagined stakeholder
for this project; I act as the analyst they hired).

**Why it matters:** after each order, customers leave a review score from 1 to 5.
Low scores are a sign that something in the order went wrong for the customer.
If we can see which parts of the order journey (delivery, product, seller,
payment) go together with low scores, the team knows where to look first.

**Working definition of "unhappy":** a review score of 1 or 2 stars.
(Final definition in section 3, KPIs.)

**What this analysis can and can't do:** it finds patterns in past orders
(things that go together). It cannot prove that one thing causes another, so
every recommendation will be something *worth testing*, not a guaranteed fix.

**Decision it supports:** where the team should run its first small tests,
e.g. trying a change with some sellers and comparing them with similar sellers
who didn't get it.

## 2. Patterns to check

Each pattern is a question about things that go together. It is not a claim
that one causes the other. They build on each other: first *is* there a problem
(P1), then *where* it shows up (P2, P3, P4), then *why the business should care* (P5).
Before any of them, a short baseline shows which orders each analysis includes
(see section 4).

### P1. Delivery promise and speed
**Is missing the promised delivery date linked with lower review scores, do scores
fall further the later the order arrives, and is slow delivery linked with lower
scores even when the promise was kept?**
- *Why the team cares:* a broken promise and a slow delivery are different problems.
  Looking at both stops "just promise later dates" from looking like a fix.
- *Measures:* days late = delivered date - promised date (bands: on time or early,
  1-3, 4-7, 8+ days late); delivery time = delivered date - purchase date.
- *Careful:* some surveys were sent before the order was delivered (when the
  promised date came first), so some ratings may have been given before the parcel
  arrived. These are flagged, not dropped.
- *Columns:* `order_purchase_timestamp`, `order_delivered_customer_date`,
  `order_estimated_delivery_date`, `review_score`

### P2. Delivery timing by stage and route
**How does delivery time split between the seller handing the order to the
carrier and the carrier's travel to the customer, and which stages and routes go
together with late deliveries and lower scores?**
- *Why the team cares:* it shows where in the journey time builds up, so a test
  can start in the right place. It describes timing patterns; it does not decide
  whose fault a delay was.
- *Careful:* the hand-over deadline (`shipping_limit_date`) is stored per item, but
  the hand-over date is stored per order. So P2 keeps only orders whose items all
  share one deadline, checked order by order in the pipeline rather than assumed
  from the seller count. Orders with several deadlines are described separately.
- *Careful:* compare travel times only between similar routes (same seller state
  to customer state, similar distance) before reading anything into them.
- *Columns:* `shipping_limit_date`, `order_delivered_carrier_date`,
  `order_delivered_customer_date`, seller and customer zip prefixes,
  `geolocation_lat` / `geolocation_lng`

### P3. Product and value
**Are some product categories, thin listings (few photos, short descriptions),
prices that are high for their category, or delivery fees that are large compared
with the price linked with lower scores, both overall and among on-time orders?**
- *Why the team cares:* showing "all orders" next to "on-time orders only" helps
  separate "the product disappointed me" from "it came late".
- *Careful:* prices are compared within a category (an expensive fridge and an
  expensive book mean different things).
- *Careful:* photo count and description length are indirect clues about the
  listing, not measures of product quality.
- *Columns:* `product_category_name`, `product_photos_qty`,
  `product_description_lenght`, `price`, `freight_value`

### P4. Seller concentration
**Do a small share of sellers account for a large share of 1-2 star reviews (by
count and by rate), and do some sellers have high bad-review rates even when they
deliver on time?**
- *Why the team cares:* a short list of sellers is a cheap, testable place to start.
  Counts show where most bad reviews sit; rates show who does worst for their size.
- *Careful:* a review belongs to an order, not an item. If an order has items from
  several sellers, we can't tell which seller the review is about. We start with
  single-seller orders and label the rest as shared.
- *Careful:* only sellers with enough orders are ranked, so small sellers don't give
  noisy rates (the minimum is set in Phase 4).
- *Columns:* `seller_id`, `review_score`, delivery dates

### P5. Business impact
**How much order value is associated with unhappy orders, and, if there is enough
data, are customers who leave a 1-2 star review less likely to order again?**
- *Why the team cares:* it puts review scores in business terms. This is order
  value *associated with* unhappy orders, not money lost.
- *Anchor:* the follow-up window starts at `review_answer_timestamp`, the moment
  the customer submitted the rating. `review_creation_date` holds only a date and
  matches when the survey was sent (usually about a day after delivery). The choice
  matters: some customers placed a new order between getting the survey and answering it.
- *Careful:* few customers in this data order more than once. So every customer
  gets the same follow-up window, we count only orders placed after they submitted their review,
  and customers whose window runs past the end of the data are left out. If too
  few customers are left, we report that as a limitation instead of forcing a conclusion.
- *Columns:* `customer_unique_id`, `order_purchase_timestamp`,
  `review_answer_timestamp`, `payment_value`, `review_score`

**Ideas we can only check partly, or not at all, with this data:**
- **Damaged or faulty products:** there is no "damaged" column. The only sign is the
  customers' own written comments (in Portuguese, and often left empty). Phase 3 can
  do a rough keyword check; proper tagging is advanced phase A1.
- **Product quality:** there is no quality rating apart from the review score itself.
- **Competitors' prices:** the dataset has only Olist's own prices.
- **Offers and discounts:** there is no discount data. Paying by `voucher` is a
  payment method; it doesn't show the customer got a lower price, so we don't use it.

## 3. KPIs

A KPI (key performance indicator) is one of the few numbers the team watches to
judge how things are going. We keep the list short: one main KPI, plus supporting
KPIs for each pattern. The breakdowns in P1-P5 (by category, seller, route...)
slice these same KPIs; they are not new KPIs.

**"Unhappy" (final definition):** an order whose review score is 1 or 2 stars.
3 stars is treated as neutral, 4-5 as satisfied.

| KPI | Plain meaning | How it's calculated | Used in |
|---|---|---|---|
| **Unhappy order rate** (main KPI) | Out of reviewed orders, how many got 1-2 stars | orders with score 1-2 ÷ orders with a review | all |
| **Average review score** | The typical star rating (1-5) | mean of `review_score` over reviewed orders | all |
| **On-time delivery rate** | How often the promise was kept | delivered orders with delivered day ≤ promised day ÷ all delivered orders with both dates (reviewed or not) | P1, P2 |
| **Days late** | How late the late orders were | delivered day - promised day, for all late delivered orders; shown as bands (1-3, 4-7, 8+) | P1 |
| **Delivery time** | How long the customer waited | median days from purchase to delivery, all delivered orders | P1, P2 |
| **Seller hand-over on time rate** | How often sellers gave the parcel to the carrier by the deadline | orders handed over on or before the shared deadline ÷ orders with one shared deadline and a hand-over date (reviewed or not) | P2 |
| **Carrier travel time** | How long the carrier took | median days from hand-over to delivery, all eligible orders, compared within similar routes | P2 |
| **Delivery fee share** | How big the delivery fee is next to the price | `freight_value` ÷ `price`, per item, all orders | P3 |
| **Seller concentration** | Whether a few sellers hold most bad reviews | share of all unhappy reviews that belong to the sellers with the most unhappy reviews (single-seller orders, sellers above a minimum order count) | P4 |
| **Order value in unhappy orders** | How much money passes through orders that end unhappy | total paid for unhappy orders, and its share of all reviewed order value | P5 |
| **Repeat purchase rate** | How often a customer comes back | customers who order again within a fixed window after submitting their review ÷ customers with that full window inside the data; compared for unhappy vs not unhappy | P5 |

**Rules for every KPI:**
- **Count the right thing once:** each order counts once, even if it has several
  reviews or payment rows (the exact rule is set in Phase 2).
- **Say what's left out:** every KPI states its denominator (the "out of how many"),
  so excluded orders are visible, not hidden.
- **Two groups, both stated:** delivery KPIs use all eligible orders, reviewed or not;
  any comparison with scores uses only the reviewed orders in that group. Results
  give both counts.
- **Dates, not times:** "on time" compares calendar days, ignoring time of day.
- **Medians for waiting times:** a few extremely long deliveries would pull an
  average up, so waiting times use the median (the middle value).
- **No tiny groups:** rates are only compared for groups with enough orders; the
  minimum is set in Phase 4.
- **Window length:** the repeat-purchase window is set in Phase 3, after checking
  how many customers have a full window before the data ends.
- **Order total:** total paid for an order = the sum of its `payment_value` rows.

No KPI values are calculated yet; they come from saved code in Phase 3.

## 4. Scope and limitations

### What's in scope
- **Data:** the 9 Olist CSV files. Kaggle describes them as orders from 2016 to
  2018; the exact date range is checked in Phase 2.
- **Main unit:** one order. Some patterns also work at item level (P3 delivery fee
  share), seller level (P4) or customer level (P5).
- **Who is included in each pattern.** Each pattern has two kinds of numbers,
  using two different groups of orders:
  - **Measurements** that don't involve ratings (e.g. how late orders were) use
    **every eligible order**, reviewed or not.
  - **Comparisons with ratings** (e.g. scores of late vs on-time orders) use only the
    **reviewed** orders within that group.

  Every result says which group it uses and how many orders are in it.

| Pattern | Measurements: all eligible orders | Comparisons with ratings: reviewed subset |
|---|---|---|
| P1 | delivered orders with a delivery date and a promised date | those P1 orders that have a review |
| P2 | P1 orders whose items share one hand-over deadline and that have a hand-over date | those P2 orders that have a review |
| P3 | all orders with items (delivery fee share, prices within category) | reviewed orders with items (all, and on-time only) |
| P4 | single-seller orders (orders and on-time rate per seller) | reviewed single-seller orders, sellers above a minimum order count |
| P5 | all orders (order value, how often customers order again) | reviewed orders; customers with a full follow-up window after their review |

**Extra check:** comparing a delivery measurement across all orders with the same
measurement on reviewed orders shows whether reviewed orders look different
(see limitation 2).

### Baseline (shown before P1-P5)
Before any pattern, we show the whole picture, so nothing is silently left out:
1. Total orders and the date range they cover.
2. Orders by status (delivered, canceled, shipped, ...).
3. Review coverage: orders with no review, one review, several reviews.
4. Orders with no items.
5. An **exclusion table** for each pattern: starting orders, how many each filter
   removes and why, and how many are left.

**Known data issues to handle in Phase 2:** some orders have more than one review,
some review IDs appear on more than one order, and a few surveys were answered
months after they were sent.

### What's out of scope
- **Things the data doesn't contain:** competitors' prices, discounts and offers,
  marketing, customer service contacts, returns and refunds.
- **Saying what a fix would achieve:** we find patterns and suggest tests; we
  don't estimate the effect of a change.
- **Advanced work (only after the core):** tagging review text (A1), predicting bad
  reviews (A2), choosing sellers under a budget (A3).

### Limitations
1. **Patterns, not causes.** Late orders may differ in other ways too (region,
   product size, seller), so a link with low scores doesn't show lateness is the reason.
2. **Only customers who answered.** People who fill in a survey may feel differently
   from those who don't, so score results describe reviewed orders, not every order.
   Delivery measurements use all orders, and comparing the two shows how different
   reviewed orders are.
3. **One review per order, not per item.** We can't always tell which product or
   seller a review is about; multi-seller orders are handled separately.
4. **Old, single-company data.** It ends in 2018 and covers one marketplace in
   Brazil, so it may not describe Olist today or other markets.
5. **Rough locations.** Locations are by zip code prefix, so distances are approximate.
6. **Thin text.** Comments are in Portuguese and often empty, so issues like damaged
   goods can only be checked roughly in the core project.
7. **Few repeat customers.** The repeat-purchase comparison in P5 may have too few
   customers to say much; if so, we report that.
8. **Cleaning choices matter.** Rules for duplicate reviews, reused review IDs and
   very late answers can change results slightly; every rule is written down in
   `docs/data_quality_report.md`.
9. **Some ratings may come before delivery.** Some surveys were sent before the order
   arrived; these orders are flagged in P1.
