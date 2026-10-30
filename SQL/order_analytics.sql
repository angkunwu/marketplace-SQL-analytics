-- Reusable model: exactly one row per source order; retain all order statuses.
-- Execute before dependent check, review, and seller files on the same connection.
-- Aggregate items and payments separately before joining to prevent inflated sums.
-- Review selection: latest answer timestamp, with review_id ASC breaking ties.
-- Eligible delay: delivered status and both actual and estimated delivery dates.
-- Delay compares calendar dates: negative = early, zero = promised day.
-- Missing related records and ineligible outcomes retain NULL values.
-- Low review = score 1-2; these outcome columns are for retrospective analysis.

CREATE OR REPLACE TEMP VIEW order_analytics AS
WITH item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(DISTINCT seller_id) AS seller_count,
        SUM(CAST(price AS DECIMAL(18,2))) AS merchandise_value,
        SUM(CAST(freight_value AS DECIMAL(18,2))) AS freight_value
    FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
    GROUP BY order_id
),
payment_summary AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        SUM(CAST(payment_value AS DECIMAL(18,2))) AS payment_value
    FROM read_csv_auto('data/raw/olist_order_payments_dataset.csv')
    GROUP BY order_id
),
ranked_reviews AS (
    SELECT
        order_id,
        review_id,
        review_score,
        review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp DESC, review_id ASC
        ) AS review_rank
    FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
),
selected_reviews AS (
    SELECT *
    FROM ranked_reviews
    WHERE review_rank = 1
),
order_base AS (
    SELECT
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        i.item_count,
        i.seller_count,
        i.merchandise_value,
        i.freight_value,
        p.payment_record_count,
        p.payment_value,
        r.review_score,
        r.review_answer_timestamp,
        i.order_id IS NOT NULL AS has_items,
        p.order_id IS NOT NULL AS has_payments,
        r.order_id IS NOT NULL AS has_review,
        o.order_delivered_customer_date IS NOT NULL AS has_actual_delivery_date,
        o.order_estimated_delivery_date IS NOT NULL AS has_estimated_delivery_date,
        CASE
            WHEN o.order_status = 'delivered'
            AND o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL
            THEN DATE_DIFF(
                'day',
                CAST(o.order_estimated_delivery_date AS DATE),
                CAST(o.order_delivered_customer_date AS DATE)
            )
            ELSE NULL
        END AS signed_delay_days
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv') o
    LEFT JOIN item_summary AS i
        ON o.order_id = i.order_id
    LEFT JOIN payment_summary AS p
        ON o.order_id = p.order_id
    LEFT JOIN selected_reviews AS r
        ON o.order_id = r.order_id
)
SELECT
    *,
    signed_delay_days > 0 AS is_late,
    review_score <= 2 AS is_low_review
FROM order_base;
