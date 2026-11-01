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
  the hand-over date is stored per order. We start with single-seller orders,
  where every item shares one deadline, and describe multi-seller orders separately.
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
- *Careful:* few customers in this data order more than once. So every customer
  gets the same follow-up window, we count only orders placed after their review,
  and customers whose window runs past the end of the data are left out. If too
  few customers are left, we report that as a limitation instead of forcing a conclusion.
- *Columns:* `customer_unique_id`, `order_purchase_timestamp`,
  `review_creation_date`, `payment_value`, `review_score`

**Ideas we can only check partly, or not at all, with this data:**
- **Damaged or faulty products:** there is no "damaged" column. The only sign is the
  customers' own written comments (in Portuguese, and often left empty). Phase 3 can
  do a rough keyword check; proper tagging is advanced phase A1.
- **Product quality:** there is no quality rating apart from the review score itself.
- **Competitors' prices:** the dataset has only Olist's own prices.
- **Offers and discounts:** there is no discount data. Paying by `voucher` is a
  payment method; it doesn't show the customer got a lower price, so we don't use it.

## 3. KPIs

_To do in Step 3._

## 4. Scope and limitations

_To do in Step 4._ Will include a **baseline**: total orders, order statuses,
how many orders have a review, and which orders each analysis leaves out (and why).
