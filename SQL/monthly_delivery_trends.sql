-- Run after SQL/order_analytics.sql on the same connection

-- Monthly delivery reliability by purchase month.
-- Retain all order statuses to show eligibility coverage.
-- Late-delivery rate uses eligible deliveries as its denominator.
-- Zero eligible deliveries produce a NULL rate.
--
-- LAG refers to the previous observed month.
-- Calendar-month changes require adjacent months.
-- Comparison support requires at least 100 eligible deliveries
-- in both adjacent months; this is a chosen sample-size threshold,
-- not a guarantee of statistical reliability or complete coverage.
--
-- Rates remain unrounded until final display.
-- Changes are expressed in percentage points.
WITH monthly_summary AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS purchase_month,
        COUNT(*) AS total_orders,
        COUNT(is_late) AS eligible_delivery_orders,
        SUM(
            CASE WHEN is_late THEN 1 ELSE 0 END
        ) AS late_orders
    FROM order_analytics
    GROUP BY purchase_month
),
monthly_rates AS (
    SELECT
        purchase_month,
        total_orders,
        eligible_delivery_orders,
        late_orders,
        100.0 * late_orders / NULLIF(eligible_delivery_orders, 0) 
            AS late_delivery_percentage,
        ROUND(
            100.0 * eligible_delivery_orders / NULLIF(total_orders, 0),
            2
        ) AS eligible_order_percentage
    FROM monthly_summary
),
monthly_with_previous AS (
    SELECT
        purchase_month,
        eligible_delivery_orders,
        late_delivery_percentage,
        LAG(late_delivery_percentage) OVER (
            ORDER BY purchase_month
        ) AS previous_observed_late_percentage,
        LAG(purchase_month) OVER(
            ORDER BY purchase_month
        ) AS previous_purchase_month,
        total_orders,
        late_orders,
        eligible_order_percentage,
        LAG(eligible_delivery_orders) OVER (
            ORDER BY purchase_month
        ) AS previous_eligible_delivery_orders
    FROM monthly_rates
)
SELECT
    purchase_month,
    eligible_delivery_orders,
    total_orders,
    late_orders,
    eligible_order_percentage,
    ROUND(late_delivery_percentage, 2) AS late_delivery_percentage,
    ROUND(previous_observed_late_percentage, 2) AS previous_observed_late_percentage,
    ROUND(
        late_delivery_percentage - previous_observed_late_percentage,
        2
    ) AS change_from_previous_observed_pp,
    CASE
        WHEN DATE_DIFF('month', previous_purchase_month, purchase_month)
            = 1
        THEN ROUND(
            late_delivery_percentage - previous_observed_late_percentage,
            2
        )
        ELSE NULL
    END AS month_over_month_change_pp,
    CASE
        WHEN DATE_DIFF('month', previous_purchase_month, purchase_month)
            = 1
            AND eligible_delivery_orders >= 100
            AND previous_eligible_delivery_orders >= 100
        THEN TRUE
        ELSE FALSE
    END AS meets_comparison_support
FROM monthly_with_previous
ORDER BY purchase_month;