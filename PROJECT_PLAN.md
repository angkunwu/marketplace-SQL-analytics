# Marketplace SQL Analytics — Project Plan
 
**Repository description:** SQL-first analysis of marketplace delivery reliability and customer outcomes using DuckDB, Python, and Olist data.  
**Suggested GitHub topics:** `sql`, `duckdb`, `python`, `data-analytics`, `data-quality`, `ecommerce`, `olist`, `portfolio-project`

This is a proposed project, not a record of completed work. Replace planned claims with verified results as milestones are completed.

## 1. Purpose and job-search goals

Build one coherent public project demonstrating the ability to turn messy relational data into correct, reproducible analysis and useful model inputs.

The project complements an existing background in physics, statistical inference, machine learning, and scientific software. Its additional contribution is evidence of practical SQL, relational-data judgment, and communication of operational findings.

Primary audiences:

- Data scientist and product/operations analytics recruiters: SQL, business metrics, data quality, and clear recommendations.
- Quantitative analytics recruiters: reliable transformations, time-aware analysis, validation, and reproducibility.
- Technical interviewers: code and decisions the author can explain, modify, and defend independently.

This project does not establish professional database tenure, production-system ownership, financial trading experience, or causal effects. A successful result should support a truthful claim of **SQL project experience**.

## 2. Central question

> Where are delivery problems concentrated, how are they associated with customer satisfaction, and which sellers or routes deserve further investigation?

Answer three questions in the first release:

1. How does delivery reliability vary over time and across sellers, product categories, and geographic regions?
2. How are delivery delays associated with review outcomes, and how stable are those associations across comparable groups?
3. Which sufficiently observed seller or regional groups combine poor reliability with substantial order volume or merchandise value?

Treat findings as observational. A recommendation to investigate a group is not evidence that the seller caused a delay or that an intervention will improve outcomes.

## 3. Dataset and provenance

Use the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), containing approximately 100,000 orders from 2016–2018 and related tables.

Core tables:

- Orders: status and purchase, approval, carrier-handoff, delivery, and estimated-delivery timestamps.
- Customers: order-linked customer IDs, persistent customer IDs, and destination geography.
- Order items: products, sellers, item prices, freight charges, and shipping-limit timestamps.
- Payments: payment records and amounts.
- Reviews: scores and review timestamps.
- Products, sellers, and category translations: supporting dimensions.

Geolocation is optional for the first release. Do not add it merely to increase the number of tables.

Record dataset version, source URL, download date, file names, checksums, license, and attribution in `data/README.md`. The source currently identifies a CC BY-NC-SA 4.0 license; verify the downloaded version's terms and distinguish dataset licensing from any code license. Keep raw data out of Git and provide acquisition instructions. A small synthetic fixture should allow tests to run without downloading the full dataset. Do not present synthetic examples as real findings.

## 4. Technology and boundaries

- **DuckDB:** local analytical database and SQL execution.
- **SQL:** cleaning, joins, metric construction, aggregation, window calculations, and feature construction.
- **Python:** reproducible execution, validation, statistical summaries, and plotting.
- **Matplotlib or Seaborn:** a small set of readable figures.
- **pytest:** focused tests of data assumptions and transformation correctness.

Do not require a database server, Docker, cloud services, paid APIs, a web application, or a complex orchestration framework for version 1. Pin a tested environment and record versions. Parameterize data paths and analysis cutoffs; do not depend on a personal absolute path or today's date.

## 5. Data model and correctness requirements

Declare the grain, key, and expected relationship of every table before joining it.

### Order-level analytical table

Create `order_analytics` with exactly one row per order. Keep the full order population at this stage and define eligible subsets for each metric explicitly.

- Aggregate order items and payments separately to order level before joining them.
- Profile review cardinality. If multiple reviews exist, adopt a documented deterministic selection rule appropriate to the analysis; do not silently average or multiply them.
- Use left joins where missing observations should remain visible.
- Verify order uniqueness and reconcile monetary totals before and after joins.
- Retain coverage indicators for missing items, payments, delivery timestamps, and reviews.

### Seller-level analysis

An order can contain several items and involve multiple sellers. Build a separate order–seller table with one row per distinct order and seller.

- Attribute item value to its actual seller.
- Label delivery dates and reviews as order-level outcomes shared across sellers on multi-seller orders.
- Do not sum seller-level order counts and claim they equal unique marketplace orders.
- Do not assign canceled orders to sellers when item/seller records are absent.
- Display sample sizes and uncertainty; define minimum-support thresholds before inspecting rankings.

### Metric definitions

- **Merchandise value:** sum of item prices under a stated status/date policy. Do not call this platform revenue or profit.
- **Payment value and freight:** report separately; explain why these need not equal merchandise value.
- **Late-delivery rate:** fraction delivered after the promised date among delivered orders with valid actual and estimated delivery timestamps. Define timestamp-versus-calendar-date treatment consistently.
- **Delay:** retain a signed difference for early/late analysis and optionally a nonnegative lateness measure.
- **Low-review rate:** prespecify a threshold, such as score 1–2, and use reviewed orders as the denominator. Report review coverage separately.
- **Time series:** define date basis, eligible order statuses, incomplete periods, and handling of missing dates.

For optional repeat-purchase analysis, use `customer_unique_id`, not the order-specific `customer_id`. Account for unequal follow-up time and do not assume repeat purchases are frequent enough to support a useful prediction task.

## 6. SQL and analytical skills to demonstrate

Use each technique where the research question needs it:

- `INNER JOIN`, `LEFT JOIN`, anti-joins, and join-cardinality checks.
- `GROUP BY`, `HAVING`, conditional aggregation, `CASE`, and null handling.
- CTEs and clear intermediate models.
- Date arithmetic and consistently defined time windows.
- Window functions such as `LAG`, `ROW_NUMBER`, rankings, and rolling summaries.
- Reconciliation queries and explicit denominator checks.
- One documented query-plan/performance investigation, if useful, with measured timings and environment details.

Aim for roughly 10–15 purposeful queries, rather than maximizing query count. Core transformations belong in readable `.sql` files rather than being hidden in pandas or a notebook.

## 7. Analysis deliverables

Produce three or four figures and a short findings report:

1. Delivery reliability over time, with eligible volume and data coverage.
2. Review outcomes by delay band, with sample sizes and uncertainty.
3. Seller or regional reliability versus order volume/value, with support thresholds.
4. Optional: a category/geography comparison that examines whether the main association persists across groups.

Document selection bias from missing reviews and delivery records, multi-seller attribution, category/geography differences, and limits of historical coverage. Estimate uncertainty at the correct unit: item or seller joins must not create artificial independent observations.

Write approximately three substantive findings. For each, include the question, metric and denominator, quantitative result, uncertainty or sensitivity check, operational interpretation, and limitation. A null or inconclusive finding is acceptable. Do not invent findings before running the analysis.

## 8. Optional ML extension — only after the SQL release works

**Prediction target:** late delivery, scored at a clearly defined purchase-time cutoff.

- Define when each feature becomes available. Exclude actual delivery outcomes, future reviews, future seller performance, and timestamps recorded after the prediction cutoff.
- Compute historical seller features strictly from information available before each order, including outcome availability time. Define cold-start handling.
- Split chronologically into train, validation, and test periods; ensure training labels would have been observable at the simulated training cutoff.
- Start with a constant baseline and logistic regression; add complexity only if it improves a meaningful evaluation.
- Report prevalence, precision–recall performance, calibration, and performance at a practical intervention capacity. Keep the test period untouched during model selection.
- Explain the decision the prediction might support without claiming tested operational impact.

The ML component is optional. A correct SQL pipeline and rigorous analysis are sufficient for version 1.

## 9. Suggested repository layout

```text
marketplace-sql-analytics/
├── README.md
├── PROJECT_PLAN.md
├── requirements.txt
├── .gitignore
├── data/
│   └── README.md
├── sql/
│   ├── 01_profile_sources.sql
│   ├── 02_order_analytics.sql
│   ├── 03_order_seller_analytics.sql
│   ├── 04_delivery_reliability.sql
│   ├── 05_review_outcomes.sql
│   └── 06_seller_region_priorities.sql
├── src/
│   ├── build_database.py
│   ├── run_analysis.py
│   └── make_figures.py
├── tests/
│   ├── fixtures/
│   └── test_sql_models.py
├── figures/
└── reports/
    ├── findings.md
    └── data_dictionary.md
```

Ignore downloaded CSVs, local database files, credentials, caches, and large intermediate outputs. Commit the small figures and findings needed to review the project without running it. A notebook may supplement the repository but should not be required to reconstruct the pipeline.

## 10. Milestones and effort budget

Use an initial budget of approximately **20–30 focused hours**, revising it as needed for learning. Stop adding features when the first release meets its acceptance criteria.

| Milestone | Deliverable | Completion criterion |
| --- | --- | --- |
| 1. Understand sources | Provenance, schema, grains, metric definitions | Can explain keys, relationships, missingness, and the central question |
| 2. Build trustworthy tables | SQL models and synthetic edge-case tests | Unique order grain; totals reconcile; joins handle one-to-many relationships correctly |
| 3. Answer the questions | Analytical queries and figures | Reproducible results with denominators, support thresholds, and limitations |
| 4. Package the showcase | README, findings report, clean rerun | Reviewer can understand the work quickly and reproduce documented outputs |
| 5. Practise explaining it | Independent walkthrough and query changes | Can write and debug the core SQL without relying on generated answers |

Only then consider ML, cohort analysis, PostgreSQL portability, or a separate SQL extension to PyIBQuant. These are future options, not version-1 requirements.

## 11. Showcase-ready acceptance criteria

- [ ] Public README clearly states the problem, dataset, approach, findings, and limitations.
- [ ] All claimed findings are backed by committed queries and reproducible outputs.
- [ ] Fresh-environment setup and execution instructions have been tested.
- [ ] Data dictionary specifies table grains, keys, feature timing, and metric denominators.
- [ ] Tests catch inflated totals from joins, duplicate reviews, missing timestamps, multi-seller orders, and null dimensions.
- [ ] Figures are readable and include units, time periods, and sample sizes where appropriate.
- [ ] No fabricated business impact, causal effects, production use, scale claims, or performance figures.
- [ ] Dataset provenance, attribution, and license handling are documented.
- [ ] No credentials or private data are committed.
- [ ] Author can explain a join-cardinality bug, a window query, a denominator choice, a limitation, and how to change the analysis.

## 12. Recruiter-facing presentation

The README should make these items visible near the top:

1. One-sentence project purpose.
2. One strong figure and a few verified findings.
3. A concise skills line: **SQL joins, CTEs, window functions, data modeling, data quality, DuckDB, Python**.
4. Links to the core SQL and findings report.
5. Short reproduction instructions and honest scope/limitations.

A suitable display title is **Marketplace Delivery Reliability — SQL Analytics**.

### Future CV wording — use only after completion

> Built a reproducible SQL/DuckDB pipeline integrating marketplace orders, payments, and reviews; validated join cardinality and monetary totals, and analyzed delivery reliability and customer outcomes.

Replace generic wording with one or two verified results when available. Describe the work as an independent project. Add it to the full master CV after completion; select it for one-page applications where relational analytics matters, preserving space for stronger research evidence elsewhere.
