DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/olist_orders_dataset.csv');

-- Check delivery-date coverage for each order status
SELECT
    order_status,
    COUNT(*) AS order_count,
    COUNT(*) - COUNT(order_delivered_customer_date)
        AS missing_actual_delivery_dates,
    COUNT(*) - COUNT(order_estimated_delivery_date)
        AS missing_estimated_delivery_dates
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
GROUP BY order_status
ORDER BY order_count DESC;

-- Delivery before purchase check
SELECT
    COUNT(*) AS delivered_before_purchase
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
WHERE order_status = 'delivered'
    AND order_delivered_customer_date < order_purchase_timestamp;

-- Promised delivery date is before the purchase date
SELECT
    COUNT(*) AS promised_before_purchase
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
WHERE order_estimated_delivery_date < order_purchase_timestamp;

-- Orders eligible for late-delivery 
SELECT
    COUNT(*) AS eligible_delivered_orders
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL;

-- Late deliveries among eligible orders
SELECT
    COUNT(*) AS late_delivered_orders
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
    AND CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE);

-- Combine and conditional aggregation
SELECT
    COUNT(*) AS eligible_delivered_orders,
    SUM(
        CASE
            WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)
            THEN 1
            ELSE 0
        END
    ) AS late_delivered_orders
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL;

-- Late delivery percentage by purchase month
WITH delivery_counts AS (
    SELECT
        COUNT(*) AS eligible_delivered_orders,
        SUM(
            CASE
                WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)
                THEN 1
                ELSE 0
            END
        ) AS late_delivered_orders,
        DATE_TRUNC('month', order_purchase_timestamp) AS purchase_month
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
    GROUP BY purchase_month
)
SELECT
    eligible_delivered_orders,
    late_delivered_orders,
    purchase_month,
    ROUND(
        100.0 * late_delivered_orders / NULLIF(eligible_delivered_orders, 0),
        2
    ) AS late_delivery_percentage
FROM delivery_counts
ORDER BY purchase_month
LIMIT 10;

-- How many days early or late each eligible order arrived
SELECT
    order_id,
    CAST(order_estimated_delivery_date AS DATE) AS promised_date,
    CAST(order_delivered_customer_date AS DATE) AS actual_date,
    DATE_DIFF(
        'day',
        CAST(order_estimated_delivery_date AS DATE),
        CAST(order_delivered_customer_date AS DATE)
    ) AS signed_delay_days
FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
ORDER BY order_id
LIMIT 10;

-- Summarize the delays across all eligible orders
WITH delivery_delays AS (
    SELECT
        order_id,
        CAST(order_estimated_delivery_date AS DATE) AS promised_date,
        CAST(order_delivered_customer_date AS DATE) AS actual_date,
        DATE_DIFF(
            'day',
            CAST(order_estimated_delivery_date AS DATE),
            CAST(order_delivered_customer_date AS DATE)
        ) AS signed_delay_days
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    COUNT(*) AS eligible_orders,
    ROUND(AVG(signed_delay_days), 2) AS mean_signed_delay_days,
    MEDIAN(signed_delay_days) AS median_signed_delay_days
FROM delivery_delays;

-- Focus on late deliveries only
WITH delivery_delays AS (
    SELECT
        order_id,
        CAST(order_estimated_delivery_date AS DATE) AS promised_date,
        CAST(order_delivered_customer_date AS DATE) AS actual_date,
        DATE_DIFF(
            'day',
            CAST(order_estimated_delivery_date AS DATE),
            CAST(order_delivered_customer_date AS DATE)
        ) AS signed_delay_days
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    COUNT(*) AS late_orders,
    ROUND(AVG(signed_delay_days), 2) AS mean_signed_delay_days,
    MEDIAN(signed_delay_days) AS median_signed_delay_days
FROM delivery_delays
WHERE signed_delay_days > 0;

-- How delays are distributed for late deliveries by putting late orders into bins
WITH delivery_delays AS (
    SELECT
        order_id,
        CAST(order_estimated_delivery_date AS DATE) AS promised_date,
        CAST(order_delivered_customer_date AS DATE) AS actual_date,
        DATE_DIFF(
            'day',
            CAST(order_estimated_delivery_date AS DATE),
            CAST(order_delivered_customer_date AS DATE)
        ) AS signed_delay_days
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    CASE
        WHEN signed_delay_days <= 7 THEN '1-7 days late'
        WHEN signed_delay_days <= 14 THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delay_band,
    COUNT(*) AS late_orders,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_late_orders
FROM delivery_delays
WHERE signed_delay_days > 0
GROUP BY delay_band
ORDER BY CASE
    WHEN delay_band = '1-7 days late' THEN 1
    WHEN delay_band = '8-14 days late' THEN 2
    ELSE 3
END;

-- Monthly coverage
WITH monthly_coverage AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS purchase_month,
        COUNT(*) AS total_orders,
        SUM(
            CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END
        ) AS delivered_orders,
        SUM(
            CASE
                WHEN order_status = 'delivered'
                    AND order_delivered_customer_date IS NOT NULL
                    AND order_estimated_delivery_date IS NOT NULL
                THEN 1 ELSE 0
            END
        ) AS eligible_orders
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
    GROUP BY purchase_month
    ORDER BY purchase_month
)
SELECT
    *,
    ROUND(
        100.0 * delivered_orders / NULLIF(total_orders, 0), 2
    ) AS delivered_percentage,
    ROUND(
        100.0 * eligible_orders / NULLIF(delivered_orders, 0), 2
    ) AS eligible_delivered_coverage_percentage
FROM monthly_coverage
ORDER BY purchase_month DESC
LIMIT 5;
-- September and October 2018 have no eligible delivered orders.
-- Late-delivery rates cannot be calculated for these purchase months.
-- Sparse boundary months require caution when interpreting time trends.

-- Overall coverage summary
WITH monthly_coverage AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS purchase_month,
        COUNT(*) AS total_orders,
        SUM(
            CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END
        ) AS delivered_orders,
        SUM(
            CASE
                WHEN order_status = 'delivered'
                    AND order_delivered_customer_date IS NOT NULL
                    AND order_estimated_delivery_date IS NOT NULL
                THEN 1 ELSE 0
            END
        ) AS eligible_orders
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
    GROUP BY purchase_month
    ORDER BY purchase_month
)
SELECT
    SUM(total_orders) AS total_orders,
    SUM(delivered_orders) AS delivered_orders,
    SUM(eligible_orders) AS eligible_orders
FROM monthly_coverage;



WITH delivery_counts AS (
    SELECT
        COUNT(*) AS eligible_delivered_orders,
        SUM(
            CASE
                WHEN CAST(order_delivered_customer_date AS DATE) > CAST(order_estimated_delivery_date AS DATE)
                THEN 1
                ELSE 0
            END
        ) AS late_delivered_orders,
        DATE_TRUNC('month', order_purchase_timestamp) AS purchase_month
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv')
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
    GROUP BY purchase_month
)
SELECT
    SUM(eligible_delivered_orders) AS eligible_delivered_orders,
    SUM(late_delivered_orders) AS late_delivered_orders,
FROM delivery_counts;