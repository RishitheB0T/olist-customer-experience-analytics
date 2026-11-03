# Phase 3 findings: what goes together with unhappy customers

This page sums up what the Phase 3 analysis found. Every number comes from the saved
queries in [`sql/questions/`](../sql/questions/) and the notebook
[`notebooks/01_trends_and_breakdowns.ipynb`](../notebooks/01_trends_and_breakdowns.ipynb),
and you can reproduce it by running them again. These are **patterns in past orders**
(things that go together), not proof that one thing causes another. Phase 4 checks
whether the gaps are bigger than chance would explain.

**Unhappy** = an order whose review score is 1 or 2 stars. If an order has several
reviews, its lowest score counts. Rates with scores use reviewed orders; delivery
measurements use all eligible orders (see [problem_brief.md](problem_brief.md)).

## In short

1. **Late delivery has the strongest link found.** 9.31% of on-time orders were unhappy,
   against 32.18% of orders 1-3 days late and 79.36% of orders 8+ days late. Part of that gap
   is linked with customers who rated before the parcel arrived (see P1).
2. **When deliveries were late, the seller had usually handed over on time.** That was true
   for 77.65% of late deliveries; for those orders the carrier took a median of 28 days, against
   7 days for on-time deliveries.
3. **Some unhappiness shows up even when delivery was on time.** Office furniture had 17.15%
   unhappy on-time orders, against 8.48% for all on-time single-product orders. Unhappy comments on on-time orders
   often mention a missing part (14.39%), a wrong item (10.79%) or damage (9.53%).
4. **Unhappy orders carry more than their share of value.** They are 14.73% of reviewed orders
   but 17.46% of reviewed order value.
5. **Too few repeat customers to say much.** Only 3.12% of people ordered more than once.
   Within 180 days, 1.33% of unhappy customers ordered again, against 1.80% of the rest.

## Baseline ([00_baseline.sql](../sql/questions/00_baseline.sql))

| Group | Orders | Reviewed | Unhappy rate | Share of all unhappy |
|---|---|---|---|---|
| All orders | 99,441 | 98,673 | 14.73% (average score 4.08) | 100% |
| Delivered | 96,478 | 95,832 | 12.85% | 84.71% |
| Not delivered (canceled, unavailable, ...) | 2,963 | 2,841 | 78.21% | 15.29% |

P1 and P2 study delivered orders only, so they leave out the 15.29% of unhappy orders that were never delivered.

## P1. Delivery promise and speed ([01_p1_delivery_promise.sql](../sql/questions/01_p1_delivery_promise.sql))

The base is 96,470 delivered orders with both dates. 93.23% were on time, with a median of
10 days to deliver against 24 days promised.

| Days late | Orders | Unhappy rate (reviewed) | Unhappy, rated after arrival | Unhappy, rated before arrival |
|---|---|---|---|---|
| On time or early | 89,936 | 9.31% | 9.28% (89,242) | 21.39% (201) |
| 1-3 days | 1,870 | 32.18% | 18.61% (1,435) | 78.90% (417) |
| 4-7 days | 1,802 | 67.68% | 20.45% (396) | 81.51% (1,352) |
| 8+ days | 2,862 | 79.36% | 30.26% (76) | 80.74% (2,705) |

- **Lateness:** the unhappy rate climbs with every lateness band.
- **Rating time:** customers who rated **before** the parcel arrived were far more often unhappy
  (78.90-81.51% in the late bands). Most ratings of 4+ day late orders came before arrival. Among
  customers who rated **after** arrival, the rate still rises from 9.28% to 30.26%, although the
  8+ days group has only 76 orders.
- **Speed when the promise was kept:** on-time orders that took 0-7 days were 7.56% unhappy;
  those that took 22+ days were 16.03% unhappy.

## P2. Delivery stages and routes ([02_p2_stages_routes.sql](../sql/questions/02_p2_stages_routes.sql))

- **Stages:** the base is 95,947 orders whose items share one hand-over deadline. The median
  order spent 2 days with the seller and 7 days with the carrier (10 days in total).
- **Late deliveries:** 77.65% had the seller hand over on time, and the median carrier part was
  28 days.
- **Seller late, delivery still on time:** 14.57% unhappy, against 8.91% when both were on time.
- **Routes:**
  - different-state routes were 13.72% unhappy, against 10.04% for same-state routes;
  - by distance, the rate rises from 10.10% (under 100 km) to 16.43% (2,000+ km);
  - the route most often late (among routes with 500+ orders) is SP → RJ: 8,032 orders, median
    382.9 km, 14.28% late, 19.82% unhappy.
- **Multi-seller orders:** they were almost never "late" (0.00% and 1.38%), yet 46.06-48.12% were
  unhappy. One recorded delivery date may not cover every parcel (limitation 4).

## P3. Product and value ([03_p3_product_value.sql](../sql/questions/03_p3_product_value.sql))

The base is reviewed single-product orders: 94,720 in total (13.54% unhappy), 86,399 of them on
time (8.48%). Looking at on-time orders keeps lateness out of the comparison.

- **Categories (26 with 500+ on-time reviewed orders):**
  - highest: office_furniture 17.15%, products with no category 11.94%, computers_accessories 10.53%;
  - lowest: luggage_accessories 5.41%, stationery 5.51%.
- **Listings and price within category:** photo count, description length and price quarter show
  small gaps. On-time rates stay between 7.80% and 8.83% for products with listing info, against
  11.94% for products with no listing info.
- **Delivery fee at least the price** (order level): 10.23% unhappy on time. These are cheap orders
  (median price 14.9 BRL), so the fee and the price can't be told apart here.
- **Fee share KPI** (all 112,650 items, reviewed or not): the median fee is 23.1% of the price, the
  90th percentile 64.3%, and 3.66% of items have a fee at least as high as the price.

## P4. Sellers ([04_p4_sellers.sql](../sql/questions/04_p4_sellers.sql))

The base is 96,653 reviewed single-seller orders from 3,073 sellers.

- **By count:** the top 10% of sellers hold 71.41% of unhappy reviews, but they also have 65.92%
  of reviewed orders. So the count mostly reflects seller size. 1,241 sellers have no unhappy review.
- **By rate:** 393 sellers have 50+ on-time reviewed orders. Of those, 25 have at least twice the
  usual on-time unhappy rate (8.77%). The worst has 54.02% (87 on-time reviewed orders).
- **Shared orders (2+ sellers):** 1,264 orders, 47.71% unhappy. They can't be assigned to one seller.

## P5. Business impact ([05_p5_business_impact.sql](../sql/questions/05_p5_business_impact.sql))

- **Value:** unhappy orders hold 2,769,252.32 of 15,859,105.79 BRL of reviewed order value
  (17.46%), and their median order is bigger (117.85 vs 103.14 BRL). This is value *associated
  with* unhappy orders, not money lost.
- **Repeat purchases:** 3.12% of people ordered more than once. We tested a 180-day window after
  the first order's review, using the 53,522 people whose full window fits in the data:
  - unhappy customers: 1.33% ordered again (103 of 7,729);
  - other customers: 1.80% (of 45,793).
  - unhappy customers also ordered again less often with 30, 90 and 365-day windows
    (0.45% vs 0.49%, 0.87% vs 1.10%, 2.53% vs 3.19%), but the counts are small.

## Review comments: a rough keyword check ([06_comment_keywords.sql](../sql/questions/06_comment_keywords.sql))

- **Who writes:** 74.77% of unhappy reviews have a written message, against 41.34% of all reviews.
- **Unhappy comments on on-time orders (6,513):** missing part 14.39%, wrong item 10.79%,
  damaged/faulty 9.53%.
- **Unhappy comments on late orders (2,749):** "not received" 53.62%.
- **A surprise:** 16.78% of unhappy on-time comments say "not received", although the order is
  recorded as delivered. This is worth checking against the multi-seller finding in P2.

## Trends and breakdowns ([notebook](../notebooks/01_trends_and_breakdowns.ipynb))

- **Months:**
  - March 2018 had the lowest on-time rate (81.04%) and the highest unhappy rate (22.80%);
  - November 2017, the busiest month (7,544 orders), was 87.60% on time and 18.82% unhappy.
- **States (500+ delivered orders):** MA had 17.43% late and 19.94% unhappy, against SP with
  4.49% and 10.71%.
- **Waiting time:** the median delivery is 10 days but the mean is 12.5, pulled up by a long
  tail: 298 of 96,470 orders took over 60 days, and the longest took 210.

## What Phase 4 checks next

- **Chance:** whether the main gaps (late vs on time, top categories, high-rate sellers, 1.33% vs
  1.80% repeat purchases) are bigger than chance would explain, and how big they are.
- **Like with like:** for example, the late vs on-time gap within similar routes, and category
  gaps within similar price levels.
- **Group sizes:** final minimum group sizes, replacing the provisional ones used here (500 orders
  for categories and routes, 50 for sellers).

## Limitations

1. **Patterns, not causes.** Late orders, far routes and some categories differ in many ways at
   once, so no single link shows the reason a customer was unhappy.
2. **Some ratings came before the parcel.** Many late orders were rated before they arrived, which
   raises unhappy rates for late orders, late months and late states.
3. **Reviewed orders only.** Score comparisons describe customers who answered the survey.
4. **Multi-seller orders:** one recorded delivery date may not cover every parcel, so their
   "on time" label may be wrong.
5. **Narrower bases:** P3 uses single-product orders and P4 single-seller orders, so each review
   belongs to one product or seller.
6. **Rough keywords.** Keywords miss some comments and catch some wrong ones, and one comment can
   match several themes. 41.89% of unhappy comments match none of them. Proper tagging is
   advanced phase A1.
7. **Provisional minimums.** The 500-order and 50-order cut-offs are set properly in Phase 4.
8. **Few repeat customers.** The repeat-purchase comparison rests on 103 unhappy customers who
   ordered again.
9. **Old, single-company data, rough locations.** The data covers one Brazilian marketplace and is
   treated as ending 2018-08-31. Distances are measured between zip code areas, not exact addresses.
