# Phase 4: are the gaps bigger than chance?

Phase 3 found gaps between groups of orders. Phase 4 asks two questions about each gap: **is it
bigger than chance would explain** (p-value), and **how big is it** (95% confidence interval).
Every number comes from [`notebooks/02_statistics.ipynb`](../notebooks/02_statistics.ipynb), which
runs top to bottom on the analytics tables. These are **associations in past orders**, not proof
that one thing causes another.

## Results

| Pattern | Comparison | Size (95% interval) | p-value |
|---|---|---|---|
| Main KPI | unhappy rate, 98,673 reviewed orders | 14.73% (14.51-14.95%) | — |
| P1 lateness | late vs on time, all reviewed | 6.71× as often unhappy (6.53-6.90) | below what the computer can show |
| P1 lateness | late vs on time, **rated after arrival** | 2.10× (1.91-2.30); +10.18 points (8.39-11.96) | 1.3e-50 |
| P1 speed | on time: 22+ days vs 0-7 days | 2.12× (1.98-2.27); 16.03% vs 7.56% | 3.2e-98 |
| P2 stages | late deliveries with the seller on time | 77.65% (76.62-78.64%) | — |
| P2 stages | on time: seller late vs seller on time | 1.64× (1.51-1.77); 14.57% vs 8.91% | 3.3e-34 |
| P2 routes | other state vs same state, 100-499 km | +3.42 points (2.75-4.08) | 4.4e-23 |
| P2 routes | other state vs same state, 500-999 km | +4.40 points (2.44-6.35) | 2.3e-04 |
| P3 categories | 26 categories (500+ on-time orders) vs the rest | 12 differ after Holm; office furniture +8.78 points (6.55-11.01) | Holm-adjusted |
| P4 sellers | 393 sellers (50+ on-time orders) vs the usual 8.77% | 24 worse than usual after Holm | one-sided binomial, Holm |
| P5 repeat | ordered again within 180 days: unhappy vs other | 0.74× (0.60-0.91); 1.33% vs 1.80% | 0.0039 |
| P5 value | unhappy share of reviewed order value | 17.46% (17.03-17.92%), against 14.73% of orders | bootstrap |

## What it means
- **Lateness:** a large part of the raw 6.71× gap is linked with customers who rated before the
  parcel arrived. Among those who rated after arrival, late orders were still unhappy about twice as
  often.
- **Speed:** slow deliveries go with more unhappiness even when the promise was kept. This holds
  within same-state routes and within other-state routes, so it isn't only distance.
- **Seller vs carrier:** most late deliveries had the seller hand over on time. At the same distance,
  other-state routes are still worse than same-state routes.
- **Categories and sellers:** after correcting for many tests, there is a short list of categories
  and 24 sellers that stand out beyond chance. These feed Phase 5 (sellers under a budget).
- **Business stake:** unhappy customers ordered again about a quarter less often, and their orders
  carry more than their share of value.

## Rules set in this phase
- **95% intervals:** Wilson for single rates, the normal formula for gaps between two rates,
  SciPy's risk-ratio interval, and the bootstrap (2,000 resamples, fixed seed) for the value share.
- **Minimum group size: 500 orders.** At the usual 8.48% on-time rate, 478 orders keep a 95% interval
  within about ±2.5 points.
- **Sellers: 50+ on-time reviewed orders,** with a one-sided binomial test that accounts for size,
  because the 500 rule would leave only 20 sellers.
- **Many tests:** the Holm correction whenever many groups are tested at once (26 categories,
  393 sellers).

## Limitations
1. **Associations, not causes.** Holding one thing equal (like distance) doesn't hold everything equal.
2. **The tests treat orders as independent.** Orders from the same seller, customer or week may move
   together, which would make the real intervals somewhat wider.
3. **0.05 is a convention.** The intervals (how big) matter more than the line.
4. **Minimum sizes are choices.** Other cut-offs would move a few borderline groups.
5. **Same bases as Phase 3:** reviewed orders only, single-product (categories) and single-seller
   (sellers) orders, data treated as ending 2018-08-31.
