-- Run after SQL/order_analytics.sql on the same DuckDB connection.
-- One selected review per order: latest answer timestamp, review_id ASC on ties.
-- Low review = score 1-2. Results describe associations, not causal effects.

-- 1. Compare late and on-time deliveries, retaining review coverage.
-- Low-review percentage uses reviewed orders as its denominator.
SELECT
    is_late,
    COUNT(*) AS eligible_orders,
    COUNT(review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(review_score) / NULLIF(COUNT(*), 0), 2)
        AS review_coverage_percentage,
    SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END) AS low_review_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END)
        / NULLIF(COUNT(review_score), 0), 2
    ) AS low_review_percentage
FROM order_analytics
WHERE is_late IS NOT NULL
GROUP BY is_late
ORDER BY is_late;

-- 2. Compare review outcomes across signed calendar-day delay bands.
-- Exclude ineligible deliveries before assigning bands.
WITH review_delay_bands AS (
    SELECT
        *,
        CASE
            WHEN signed_delay_days <= 0 THEN 'On time or early'
            WHEN signed_delay_days <= 7 THEN '1-7 days late'
            WHEN signed_delay_days <= 14 THEN '8-14 days late'
            ELSE '15+ days late'
        END AS delay_band
    FROM order_analytics
    WHERE signed_delay_days IS NOT NULL
)
SELECT
    delay_band,
    COUNT(*) AS eligible_orders,
    COUNT(review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(review_score) / NULLIF(COUNT(*), 0), 2)
        AS review_coverage_percentage,
    SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END) AS low_review_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END)
        / NULLIF(COUNT(review_score), 0), 2
    ) AS low_review_percentage
FROM review_delay_bands
GROUP BY delay_band
ORDER BY CASE
    WHEN delay_band = 'On time or early' THEN 0
    WHEN delay_band = '1-7 days late' THEN 1
    WHEN delay_band = '8-14 days late' THEN 2
    ELSE 3
END;

-- 3. Review timing among reviewed eligible orders; compare full timestamps.
SELECT
    is_late,
    COUNT(*) AS reviewed_eligible_orders,
    SUM(
        CASE WHEN review_answer_timestamp < order_delivered_customer_date
            THEN 1 ELSE 0 END
    ) AS reviews_before_delivery
FROM order_analytics
WHERE signed_delay_days IS NOT NULL
  AND review_score IS NOT NULL
GROUP BY is_late
ORDER BY is_late;

-- 4. Sensitivity check: selected reviews answered at or after delivery.
-- Filtering changes the population; this subset can differ systematically.
-- All remaining orders are reviewed, so COUNT(*) is the denominator here.
SELECT
    is_late,
    COUNT(*) AS reviewed_orders,
    SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END) AS low_review_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS low_review_percentage
FROM order_analytics
WHERE signed_delay_days IS NOT NULL
  AND review_score IS NOT NULL
  AND review_answer_timestamp >= order_delivered_customer_date
GROUP BY is_late
ORDER BY is_late;
