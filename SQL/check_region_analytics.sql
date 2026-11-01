-- Run after order_analytics.sql and region_analytics.sql

-- 1. Return any order appearing more than once
SELECT
    order_id,
    COUNT(*) AS rows_per_order
FROM order_region_analytics
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 2. Check whether any orders disappeared when creating the regional view
SELECT
    o.order_id
FROM order_analytics AS o
LEFT JOIN order_region_analytics AS r
    ON o.order_id = r.order_id
WHERE r.order_id IS NULL;

-- 3. Return regional orders absent from the source order model
SELECT
    r.order_id
FROM order_region_analytics AS r
LEFT JOIN order_analytics AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 4. Return orders without a destination state
SELECT
    order_id,
    customer_id,
    customer_state
FROM order_region_analytics
WHERE customer_state IS NULL;

-- 5. Verify that adding geography preserved the merchandise total
-- Compare merchandise totals before and after the regional join
WITH source_total AS (
    SELECT
        SUM(merchandise_value) AS merchandise_total
    FROM order_analytics
),
region_total AS (
    SELECT
        SUM(merchandise_value) AS merchandise_total
    FROM order_region_analytics
)
SELECT
    s.merchandise_total AS source_total,
    r.merchandise_total AS region_total
FROM source_total AS s
CROSS JOIN region_total AS r;

-- 6. Return orders whose merchandise value changed.
SELECT
    o.order_id,
    o.merchandise_value AS source_value,
    r.merchandise_value AS region_value
FROM order_analytics AS o
JOIN order_region_analytics AS r
    ON o.order_id = r.order_id
WHERE o.merchandise_value IS DISTINCT FROM r.merchandise_value;

-- 7. Return orders whose delivery or review outcomes changed
SELECT
    o.order_id,
    o.is_late AS source_is_late,
    r.is_late AS region_is_late,
    o.review_score AS source_review_score,
    r.review_score AS region_review_score
FROM order_analytics AS o
JOIN order_region_analytics AS r
    ON o.order_id = r.order_id
WHERE o.is_late IS DISTINCT FROM r.is_late
   OR o.review_score IS DISTINCT FROM r.review_score;

-- Validation checks for order_region_analytics.
-- Run after order_analytics.sql and region_analytics.sql
-- on the same DuckDB connection.
--
-- Queries 1–4 and 6–7: expect zero rows.
-- Query 5: expect matching merchandise totals.
--
-- These checks inspect the current dataset.
-- The runner displays results; it does not automatically fail
-- when a check returns unexpected rows.

