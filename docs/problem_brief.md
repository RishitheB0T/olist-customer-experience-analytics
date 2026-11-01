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
(P1), then *where* it happens (P2, P3, P4), then *why the business should care* (P5).

### P1. Delivery promise
**Is missing the promised delivery date linked with lower review scores, and do
scores fall further the later the order arrives?**
- *Why the team cares:* the promised date is something Olist sets and can change.
- *Columns:* `order_delivered_customer_date`, `order_estimated_delivery_date`,
  `order_purchase_timestamp`, `review_score`
- *Skills shown:* date maths in SQL, grouping orders into lateness bands
  (on time, 1-3 days late, 4-7, 8+), comparing groups.

### P2. Where in the delivery journey
**Is lateness linked more with sellers handing orders over late, or with the
carrier's travel time, and with which routes (seller state to customer state,
distance)?**
- *Why the team cares:* it tells them *who* to test a fix with: sellers or carriers.
- *Columns:* `shipping_limit_date` (seller's hand-over deadline),
  `order_delivered_carrier_date`, `order_delivered_customer_date`,
  seller and customer zip prefixes, `geolocation_lat` / `geolocation_lng`
- *Skills shown:* splitting one delay into stages, multi-table joins,
  distance from latitude/longitude, route-level summaries.

### P3. Product and value (when delivery went fine)
**Among orders delivered on time, are some product categories, thin listings
(few photos, short descriptions), high prices or high delivery fees compared with
the price linked with lower scores?**
- *Why the team cares:* looking only at on-time orders separates "the product
  disappointed me" from "it came late".
- *Columns:* `product_category_name`, `product_photos_qty`,
  `product_description_lenght`, `price`, `freight_value`, `payment_type` (voucher)
- *Skills shown:* comparing like with like (holding delivery fixed), ratios
  such as fee ÷ price.

### P4. Seller concentration
**Do a small share of sellers account for a large share of 1-2 star reviews, and
do some sellers still get low scores even when they deliver on time?**
- *Why the team cares:* a short list of sellers to work with first is a cheap,
  testable action.
- *Columns:* `seller_id`, `review_score`, delivery dates
- *Skills shown:* running totals with SQL window functions (the 80/20 check),
  a minimum number of orders per seller so small sellers don't give noisy results.

### P5. Business impact
**Are customers who leave a 1-2 star review less likely to order again, and how
much order value is linked with unhappy orders?**
- *Why the team cares:* it turns review scores into money and repeat business.
- *Columns:* `customer_unique_id` (the same person across orders),
  `order_purchase_timestamp`, `payment_value`, `review_score`
- *Skills shown:* following customers over time (repeat purchase), revenue
  summaries.

**Ideas we can only check partly, or not at all, with this data:**
- **Damaged or faulty products:** there is no "damaged" column. The only sign is the
  customers' own written comments (in Portuguese, and often left empty). Phase 3 can
  do a rough keyword check; proper tagging is advanced phase A1.
- **Product quality:** there is no quality rating apart from the review score itself.
- **Competitors' prices:** the dataset has only Olist's own prices.
- **Offers and discounts:** there is no discount column; paying with a `voucher` is the closest sign.

## 3. KPIs

_To do in Step 3._

## 4. Scope and limitations

_To do in Step 4._
