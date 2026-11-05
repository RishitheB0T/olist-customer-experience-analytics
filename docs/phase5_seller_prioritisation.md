# Phase 5: which sellers should a limited budget go to first?

Phase 4 found 24 sellers whose **on-time** orders were unhappy more often than usual, beyond chance.
Olist can't help them all at once. Phase 5 uses **linear programming** (PuLP with the HiGHS solver)
to choose which sellers to include in a pilot under a fixed budget. Every number comes from
[`notebooks/03_seller_prioritisation.ipynb`](../notebooks/03_seller_prioritisation.ipynb). The data
has no costs, so **costs and benefits are written-down assumptions**, and the output is a shortlist
**worth testing**, not a promise of results.

## The candidates (from the data)
- 24 sellers, 7,821 reviewed on-time orders, against a usual on-time unhappy rate of 8.77%.
- Together they had **686 excess unhappy orders** (unhappy orders above the usual rate), or 425
  using the low end of each seller's 95% interval. The 5 biggest hold 47%.
- Rate and excess rank sellers differently: the highest rate (54.0%, 87 orders) is only 5th by excess.

## The assumptions (not from the data)
| Assumption | Main value | Also tried |
|---|---|---|
| Pilot length | 3 months | — |
| Fixed cost per seller (coaching, listing review) | 1,000 cost units | 500, 2,000 |
| Cost per pilot order (extra packing / quality check) | 5 units | 2, 10 |
| Share of excess a fix removes | 30% | 10%, 50% (changes the size, not the choice) |
| Benefit basis | excess as measured | careful excess (interval's low end) |
| Budget | 8,000 units | 6,000, 10,000 |
| Most sellers the team can coach | 6 | 4, 8 |

## Results
- **Main choice:** 5 sellers costing 7,975 of 8,000 units, expected to avoid about **25.8 unhappy
  orders** in 3 months (about 9-43 if a fix removes 10-50% of the excess). Money is the binding limit.
- **Model vs simple rules (same budget):**

| Rule | Sellers | Expected unhappy orders avoided |
|---|---|---|
| Model (PuLP) | 5 | 25.8 |
| Best value for money first | 6 | 25.2 |
| Most excess first | 4 | 20.8 |
| Worst rate first | 6 | 19.6 |

- **Sensitivity (162 scenarios):** only 11 of 24 sellers are ever chosen.
  - **Core:** 2eb70248 and 1ca7077d (chosen in 100%), 7c67e144 (85%).
  - **Often:** 6560211a (48%) and 88460e8e (45%).
  - **Never chosen:** 13 sellers.
- Full ranked list: [`phase5_seller_shortlist.csv`](phase5_seller_shortlist.csv).

## What it means
- **Start a pilot with the 3 core sellers;** they are chosen whatever we assume. The next 2 are good
  additions if the budget allows.
- **A budget model beats "worst rate first",** which spends on small sellers with few orders to fix.
- **The expected effect is small in absolute numbers** (tens of orders), so a fair test needs to be
  sized carefully. Phase 7 designs it: give the change to some sellers and compare them with similar
  sellers who didn't get it.

## Limitations
1. **Costs and benefits are assumptions,** not data. Only a real test can show what a fix costs and
   how much it helps.
2. **Past excess may not continue,** and very high rates tend to drift back towards usual on their
   own (regression to the mean), so a before-and-after comparison would overstate any effect.
3. **Only on-time, single-seller, reviewed orders** are counted, so orders per month and the
   per-order cost are lower than each seller's real volume.
4. **Excess per month favours sellers with short histories,** because the same excess over fewer
   months counts as more per month.
5. **Being chosen is not proof the seller is the cause:** products, customers and regions differ
   between sellers too.
