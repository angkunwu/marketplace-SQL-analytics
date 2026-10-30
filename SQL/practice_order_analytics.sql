-- Order status and delivery dates.
-- Aggregated item counts, merchandise value, and freight.
-- Aggregated payment value.
-- The selected review and indicators for missing data.

-- 1. Item summary
WITH item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(DISTINCT seller_id) AS seller_count,
        SUM(CAST(price AS DECIMAL(18,2))) AS merchandise_value,
        SUM(CAST(freight_value AS DECIMAL(18,2))) AS freight_value
    FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
    GROUP BY order_id
)
SELECT *
FROM item_summary
ORDER BY item_count DESC, order_id
LIMIT 10;

-- 2. Payment summary with item_summary
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
    ORDER BY order_id, review_rank
),
selected_reviews AS (
    SELECT *
    FROM ranked_reviews
    WHERE review_rank = 1
)
SELECT
    COUNT(*) AS  joined_rows,
    COUNT(DISTINCT o.order_id) AS distinct_orders,
    COUNT(i.order_id) AS orders_with_items,
    COUNT(p.order_id) AS orders_with_payments,
    COUNT(r.order_id) AS orders_with_reviews
FROM read_csv_auto('data/raw/olist_orders_dataset.csv') o
LEFT JOIN item_summary AS i
    ON o.order_id = i.order_id
LEFT JOIN payment_summary AS p
    ON o.order_id = p.order_id
LEFT JOIN selected_reviews AS r
    ON o.order_id = r.order_id;

-- 3. Inspect the actual analytical columns
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
    ORDER BY order_id, review_rank
),
selected_reviews AS (
    SELECT *
    FROM ranked_reviews
    WHERE review_rank = 1
)
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
ORDER BY o.order_id
LIMIT 10;

-- 4. Make the combined records 
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
    ORDER BY order_id, review_rank
),
selected_reviews AS (
    SELECT *
    FROM ranked_reviews
    WHERE review_rank = 1
),
order_analytics AS (
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
    ORDER BY o.order_id
) 
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(signed_delay_days) AS eligible_delivered_orders,
    SUM(
        CASE WHEN signed_delay_days > 0 THEN 1 ELSE 0 END
    ) AS late_orders
FROM order_analytics;
    
-- 5. Make the combined records 
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
    ORDER BY order_id, review_rank
),
selected_reviews AS (
    SELECT *
    FROM ranked_reviews
    WHERE review_rank = 1
),
order_analytics AS (
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
    ORDER BY o.order_id
) 
SELECT
    -- SUM(merchandise_value) AS joined_merchandise_total,
    -- (SELECT SUM(merchandise_value) FROM item_summary) AS source_merchandise_total,
    -- SUM(freight_value) AS joined_freight_total,
    -- (SELECT SUM(freight_value) FROM item_summary) AS source_freight_total,
    -- SUM(payment_value) AS joined_payment_total,
    -- (SELECT SUM(payment_value) FROM payment_summary) AS source_payment_total
    order_id,
    signed_delay_days,
    signed_delay_days > 0 AS is_late,
    review_score,
    review_score <= 2 AS is_low_review
FROM order_analytics
WHERE signed_delay_days > 0
    OR review_score <= 2
    OR signed_delay_days IS NULL
    OR review_score IS NULL
ORDER BY order_id
LIMIT 5;

-- 6. check review coverage among eligible deliveries
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
    ORDER BY order_id, review_rank
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
    ORDER BY o.order_id
),
order_analytics AS (
    SELECT 
        *,
        signed_delay_days > 0 AS is_late,
        review_score <= 2 AS is_low_review
    FROM order_base
)
SELECT
    is_late,
    COUNT(*) AS eligible_orders,
    COUNT(review_score) AS reviewed_orders,
    ROUND(
        100.0 * COUNT(review_score) / COUNT(*), 2
    ) AS review_coverage_percentage,
    SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END) AS low_review_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END) 
        / NULLIF(COUNT(review_score),0), 2
    ) AS low_review_percentage
FROM order_analytics
WHERE is_late IS NOT NULL
GROUP BY is_late
ORDER BY is_late;

-- 7. Examine whether low-review rates vary with delay severity.
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
    ORDER BY order_id, review_rank
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
    ORDER BY o.order_id
),
order_analytics AS (
    SELECT 
        *,
        signed_delay_days > 0 AS is_late,
        review_score <= 2 AS is_low_review
    FROM order_base
),
review_delay_bands AS (
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
-- SELECT
--     delay_band,
--     COUNT(*) AS eligible_orders,
--     COUNT(review_score) AS reviewed_orders,
--     ROUND(
--         100.0 * COUNT(review_score) / COUNT(*), 2
--     ) AS review_coverage_percentage,
--     SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END) AS low_review_orders,
--     ROUND(
--         100.0 * SUM(CASE WHEN is_low_review THEN 1 ELSE 0 END) 
--         / NULLIF(COUNT(review_score),0), 2
--     ) AS low_review_percentage
-- FROM review_delay_bands
-- GROUP BY delay_band
-- ORDER BY CASE
--     WHEN delay_band = 'On time or early' THEN 0
--     WHEN delay_band = '1-7 days late' THEN 1
--     WHEN delay_band = '8-14 days late' THEN 2
--     ELSE 3
-- END;
-- SELECT
--     is_late,
--     COUNT(*) AS reviewed_eligible_orders,
--     SUM(
--         CASE WHEN review_answer_timestamp < order_delivered_customer_date THEN 1 ELSE 0 END
--     ) AS reviews_before_delivery
-- FROM order_analytics
-- WHERE signed_delay_days IS NOT NULL
--     AND review_score IS NOT NULL
-- GROUP BY is_late
-- ORDER BY is_late;
SELECT
    is_late,
    COUNT(*) AS reviewed_orders,
    SUM(
        CASE WHEN is_low_review THEN 1 ELSE 0 END
    ) AS low_review_orders,
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

-- 7. Define the model once as a temporary review
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
    ORDER BY order_id, review_rank
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
    ORDER BY o.order_id
)
SELECT 
    *,
    signed_delay_days > 0 AS is_late,
    review_score <= 2 AS is_low_review
FROM order_base;
-- Validate order again
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM order_analytics;
-- Validate delivery and review coverage
SELECT
    COUNT(is_late) AS eligible_delivery_orders,
    COUNT(is_low_review) AS reviewed_orders,
    SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS late_orders
FROM order_analytics;