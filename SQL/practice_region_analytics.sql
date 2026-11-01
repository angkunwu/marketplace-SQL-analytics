-- Run after SQL/order_analytics.sql and SQL/region_analytics.sql
-- on the same DuckDB connection.

-- Among states with at least 100 eligible deliveries,
-- the eight states with the most late orders account for
-- 5,259 late orders (80.61% of late orders in qualifying states).
-- States: SP, RJ, MG, BA, RS, SC, ES, PR.

-- 1. Analyze delivery reliability by customer destination state
SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(*) - COUNT(customer_id) AS missing_customer_ids,
    COUNT(*) - COUNT(customer_state) AS missing_states
FROM read_csv_auto('data/raw/olist_customers_dataset.csv');

-- 2. Check whether every order matches a customer
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT o.order_id) AS distinct_orders,
    COUNT(c.customer_id) AS orders_with_customers,
    COUNT(*) - COUNT(c.customer_id) AS orders_without_customers
FROM read_csv_auto('data/raw/olist_orders_dataset.csv') AS o
LEFT JOIN read_csv_auto('data/raw/olist_customers_dataset.csv') AS c
    ON o.customer_id = c.customer_id;
-- 3. Analyze orders without customer state
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(customer_state) AS orders_without_state
FROM order_region_analytics;

-- 4. Analyze late delivery performance by customer state
SELECT
    customer_state,
    COUNT(*) AS total_orders,
    COUNT(is_late) AS eligible_delivery_orders,
    SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_late THEN 1 ELSE 0 END)
        / NULLIF(COUNT(is_late), 0),
        2
    ) AS late_delivery_percentage
FROM order_region_analytics
GROUP BY customer_state
HAVING COUNT(is_late) >= 100
ORDER BY 
    1.0 * SUM(CASE WHEN is_late THEN 1 ELSE 0 END)
        / NULLIF(COUNT(is_late),0) DESC,
    eligible_delivery_orders DESC, customer_state;

-- 5. Check whether late orders receive more low reviews within each state
SELECT
    customer_state,
    is_late,
    COUNT(*) AS eligible_orders,
    COUNT(review_score) AS reviewed_orders,
    ROUND(
        100.0 * COUNT(review_score) / NULLIF(COUNT(*), 0),
        2
    ) AS review_coverage_percentage,
    SUM(
        CASE WHEN is_low_review THEN 1 ELSE 0 END
    ) AS low_review_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END)
        / NULLIF(COUNT(review_score), 0),
        2
    ) AS low_review_percentage
FROM order_region_analytics
WHERE is_late IS NOT NULL
GROUP BY customer_state, is_late
ORDER BY customer_state, is_late
LIMIT 5;

-- 6. State comparison: all reviewed eligible deliveries.
-- One row per state; require at least 30 reviewed orders in each group.
WITH state_summary AS (
    SELECT
        customer_state,
        COUNT(CASE WHEN is_late = FALSE THEN review_score END) AS on_time_reviewed_orders,
        COUNT(CASE WHEN is_late = TRUE THEN review_score END) AS late_reviewed_orders,
        COUNT(CASE WHEN is_late = FALSE AND is_low_review = TRUE THEN 1 END) AS on_time_low_review_orders,
        COUNT(CASE WHEN is_late = TRUE AND is_low_review = TRUE THEN 1 END) AS late_low_review_orders
    FROM order_region_analytics
    WHERE is_late IS NOT NULL
    GROUP BY customer_state
),
state_rates AS (
    SELECT
        customer_state,
        on_time_reviewed_orders,
        late_reviewed_orders,
        100.0 * on_time_low_review_orders
            / NULLIF(on_time_reviewed_orders, 0) AS on_time_low_review_percentage,
        100.0 * late_low_review_orders
            / NULLIF(late_reviewed_orders, 0) AS late_low_review_percentage
    FROM state_summary
    WHERE on_time_reviewed_orders >= 30
        AND late_reviewed_orders >= 30
)
SELECT
    customer_state,
    on_time_reviewed_orders,
    late_reviewed_orders,
    ROUND(on_time_low_review_percentage, 2) AS on_time_low_review_percentage,
    ROUND(late_low_review_percentage, 2) AS late_low_review_percentage,
    ROUND(late_low_review_percentage - on_time_low_review_percentage, 
        2
    ) AS low_review_gap_pp
FROM state_rates
ORDER BY low_review_gap_pp ASC, customer_state;
-- Among states with at least 30 reviewed orders in each delivery group,
-- low-review rates were consistently higher for late deliveries.
-- The within-state gaps ranged from 42.68 to 67.64 percentage points.
-- This is an observational association; review timing and other
-- differences between orders may affect the comparison.

-- 7. Timing sensitivity check: reviews answered at or after delivery.
-- Apply the same minimum counts to this smaller population.
WITH state_summary AS (
    SELECT
        customer_state,
        COUNT(CASE
            WHEN is_late = FALSE THEN review_score
        END) AS on_time_reviewed_orders,
        COUNT(CASE
            WHEN is_late = TRUE THEN review_score
        END) AS late_reviewed_orders,
        COUNT(CASE
            WHEN is_late = FALSE AND is_low_review = TRUE THEN 1
        END) AS on_time_low_review_orders,
        COUNT(CASE
            WHEN is_late = TRUE AND is_low_review = TRUE THEN 1
        END) AS late_low_review_orders
    FROM order_region_analytics
    WHERE is_late IS NOT NULL
      AND review_answer_timestamp >= order_delivered_customer_date
    GROUP BY customer_state
),
state_rates AS (
    SELECT
        customer_state,
        on_time_reviewed_orders,
        late_reviewed_orders,
        100.0 * on_time_low_review_orders
            / NULLIF(on_time_reviewed_orders, 0)
            AS on_time_low_review_percentage,
        100.0 * late_low_review_orders
            / NULLIF(late_reviewed_orders, 0)
            AS late_low_review_percentage
    FROM state_summary
    WHERE on_time_reviewed_orders >= 30
      AND late_reviewed_orders >= 30
)
SELECT
    customer_state,
    on_time_reviewed_orders,
    late_reviewed_orders,
    ROUND(on_time_low_review_percentage, 2)
        AS on_time_low_review_percentage,
    ROUND(late_low_review_percentage, 2)
        AS late_low_review_percentage,
    ROUND(
        late_low_review_percentage - on_time_low_review_percentage,
        2
    ) AS low_review_gap_pp
FROM state_rates
ORDER BY low_review_gap_pp ASC, customer_state;

-- 8. Review timing among reviewed late deliveries.
WITH review_timing_summary AS (
    SELECT
        customer_state,
        COUNT(*) as late_reviewed_orders,
        COUNT(CASE WHEN review_answer_timestamp >= order_delivered_customer_date THEN 1 END)
            AS late_reviews_at_or_after_delivery,
        COUNT(CASE WHEN review_answer_timestamp < order_delivered_customer_date THEN 1 END)
            AS late_reviews_before_delivery,
        COUNT(CASE WHEN review_answer_timestamp IS NULL THEN 1 END) AS late_reviews_missing,
        ROUND(
            100.0 * COUNT(CASE 
                WHEN review_answer_timestamp < order_delivered_customer_date THEN 1 
                END
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS percentage_late_reviews_before_delivery
    FROM order_region_analytics
    WHERE is_late = TRUE
        AND review_score IS NOT NULL
    GROUP BY customer_state
)
SELECT
    customer_state,
    late_reviewed_orders,
    late_reviews_at_or_after_delivery,
    late_reviews_before_delivery,
    late_reviews_missing,
    ROUND(
        100.0 * late_reviews_before_delivery
        / NULLIF(late_reviewed_orders, 0),
        2
    ) AS percentage_late_reviews_before_delivery,
    late_reviewed_orders - late_reviews_before_delivery
        - late_reviews_missing - late_reviews_at_or_after_delivery
        AS reconciliation_difference
FROM review_timing_summary
ORDER BY percentage_late_reviews_before_delivery DESC, customer_state;

-- Validation: review timing counts reconcile for every state.
-- Reviewed late orders = reviews before delivery
--     + reviews at/after delivery + reviews missing a timestamp.
--
-- In RJ, 1,168 of 1,456 reviewed late orders (80.22%)
-- were reviewed before delivery.
-- Restricting reviews to at/after delivery substantially changes
-- the population and the within-state low-review gaps.
-- The filtered comparison is a sensitivity check;

-- 9. Rank states by late-order volume
WITH state_delivery_summary AS (
    SELECT
        customer_state,
        COUNT(is_late) AS eligible_delivery_orders,
        SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS late_orders
    FROM order_region_analytics
    GROUP BY customer_state
    Having COUNT(is_late) >= 100
),
ranked_states AS (
    SELECT
        customer_state,
        eligible_delivery_orders,
        late_orders,
        ROUND(
            100.0 * late_orders / NULLIF(eligible_delivery_orders, 0),
            2
        ) AS late_delivery_percentage,
        RANK() OVER (ORDER BY late_orders DESC) AS volume_rank,
        RANK() OVER (ORDER BY 1.0 * late_orders / NULLIF(eligible_delivery_orders, 0) DESC) AS rate_rank,
        ROUND(
            100.0 * late_orders / NULLIF(SUM(late_orders) OVER(), 0),
            2
        ) AS percentage_of_late_orders
    FROM state_delivery_summary
)
-- SELECT
--     *,
--     CASE
--         WHEN volume_rank <= 5 AND rate_rank <= 5 THEN 'Both'
--         WHEN volume_rank <= 5 THEN 'Volume'
--         ELSE 'Rate'
--     END AS investigation_reason
-- FROM ranked_states
-- WHERE volume_rank <= 5
--     OR rate_rank <= 5
-- ORDER BY volume_rank, customer_state;
, cumulative_states AS (
    SELECT
        customer_state,
        late_orders,
        ROW_NUMBER() OVER(
            ORDER BY late_orders DESC, customer_state
        ) AS states_included,
        SUM(late_orders) OVER(
            ORDER BY late_orders DESC, customer_state
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_late_orders,
        SUM(late_orders) OVER () AS total_late_orders
    FROM state_delivery_summary
)
SELECT
    customer_state,
    states_included,
    cumulative_late_orders,
    ROUND(
        100.0 * cumulative_late_orders / NULLIF(total_late_orders, 0),
        2
    ) AS cumulative_late_percentage
FROM cumulative_states
WHERE 1.0 * cumulative_late_orders
    / NULLIF(total_late_orders, 0) >= 0.80
ORDER BY states_included ASC
LIMIT 1;