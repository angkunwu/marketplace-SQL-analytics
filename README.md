# Marketplace Delivery Reliability — SQL Analytics

Where are delivery problems concentrated, and how are they associated with customer reviews?

An independent analysis of **99,441 Brazilian marketplace orders** from the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle (2016–2018), using SQL for transformations and analysis, DuckDB for execution, and Python for validation and reporting.

**SQL skills:** joins, CTEs, conditional aggregation, window functions, date arithmetic, null handling, data modeling, and reconciliation.

![Delivery reliability by purchase month](figures/monthly_delivery_reliability.png)

- **Time:** March 2018 had the highest late-delivery rate among months with at least 100 eligible deliveries: **18.96%** (1,328 / 7,003).
- **Reviews:** low scores occurred in **62.42%** of reviewed late orders versus **9.27%** of reviewed on-time/early orders. Restricting to reviews answered at or after delivery changes the late-order rate to **19.44%**, showing substantial sensitivity to review timing.
- **Geography:** the eight states with the most late orders accounted for **80.61%** of late orders among states meeting the support threshold. Priorities differ when ranked by rate versus affected volume.

Read the [findings and limitations](reports/findings.md), or inspect the [review](figures/review_outcomes.png) and [regional](figures/regional_priorities.png) figures. These are historical associations; they do not establish causes or tested business impact.

## Selected SQL

**SQL approach:** Built an order-level analytical view using CTEs and left joins. Items and payments are aggregated separately before joining to avoid inflating totals, while `ROW_NUMBER()` selects one review per order. Conditional aggregation calculates rates with explicit eligibility rules, and `LAG()` supports monthly comparisons with calendar-adjacency checks. Validation queries check order uniqueness, population preservation, and monetary reconciliation.

| Example | Decision demonstrated |
| --- | --- |
| [Order model](SQL/order_analytics.sql) | Aggregate items and payments separately before joining; retain all orders; select one review with `ROW_NUMBER()` |
| [Monthly trends](SQL/monthly_delivery_trends.sql) | Use `LAG()` while distinguishing previous observed months from consecutive calendar months |
| [Review outcomes](SQL/review_outcomes.sql) | Define reviewed-order denominators, delay bands, and a review-timing sensitivity comparison |
| [Regional analysis](SQL/practice_region_analytics.sql) | Filter by minimum support, compare rates, rank states, and calculate cumulative shares |
| [Regional checks](SQL/check_region_analytics.sql) | Check uniqueness, population preservation, monetary totals, and unchanged outcomes |

The [model and query guide](docs/analysis_guide.md) includes a diagram, execution order, and the full file inventory. The [data dictionary](reports/data_dictionary.md) defines grains and denominators. Exploratory SQL is retained alongside reusable models; final reporting reuses those queries.

## Reproduce

Use Python 3.11. Download and extract the Olist CSVs to `data/raw/` following the [data instructions](data/README.md), then run from the repository root:

```bash
python3.11 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python validate_analysis.py
.venv/bin/python make_figures.py
```

The synthetic tests run without downloading Olist. Full-data validation and figure generation require the CSVs. Reporting writes three PNGs to `figures/` and five result CSVs to `reports/results/`. Direct dependencies are pinned in `requirements.txt`; setup, validation, and reporting were verified in a fresh Python 3.11 environment ([verification](docs/validation.md)).

To inspect monthly results directly:

```bash
.venv/bin/python run_duckdb.py SQL/order_analytics.sql SQL/monthly_delivery_trends.sql
```

Temporary views exist only within one DuckDB connection; pass prerequisite SQL files in the same invocation. `run_duckdb.py` displays query results; `validate_analysis.py` asserts full-data checks and exits nonzero on failure.

## Validation and scope

Synthetic tests exercise the unchanged SQL against multiple items and payments, duplicate reviews, missing timestamps and customer matches, multi-seller orders, calendar gaps, and zero eligible deliveries. Full-data checks reconcile monetary totals and regional/monthly populations. See [validation details](docs/validation.md).

This release covers time, reviews, and destination states. Seller queries are available as supporting exploration. Category-adjusted comparisons and predictive modeling are outside this release. Missing outcomes, review selection, and seller/product/time differences limit interpretation; the findings report describes these limits.

Code is MIT-licensed. Olist data has separate attribution and licensing requirements; see [data provenance](data/README.md).
