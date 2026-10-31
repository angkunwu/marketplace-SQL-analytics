-- 1. Check full order-seller population
CREATE OR REPLACE TEMP VIEW order_seller_summary AS 
SELECT
    order_id,
    seller_id,
    COUNT(*) AS item_count,
    SUM(CAST(price AS DECIMAL(18,2))) AS merchandise_value,
    SUM(CAST(freight_value AS DECIMAL(18,2))) AS freight_value
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
GROUP BY order_id, seller_id;

-- SELECT
--     COUNT(*) AS order_seller_pairs,
--     COUNT(DISTINCT order_id) AS distinct_orders,
--     COUNT(DISTINCT seller_id) AS distinct_sellers,
--     SUM(item_count) AS total_items,
--     SUM(merchandise_value) AS merchandise_total,
--     SUM(freight_value) AS freight_total
-- FROM order_seller_summary;
SELECT
    *
FROM order_seller_summary
WHERE order_id = '1c11d0f4353b31ac3417fbfa5f0f2a8a'
ORDER BY seller_id;

-- attach order-level delivery and review outcomes to each order-seller pair
CREATE OR REPLACE TEMP VIEW order_seller_analytics AS
SELECT
    s.order_id,
    s.seller_id,
    s.item_count,
    s.merchandise_value,
    s.freight_value,
    o.order_status,
    o.order_purchase_timestamp,
    o.signed_delay_days,
    o.is_late,
    o.review_score,
    o.is_low_review,
    o.seller_count
FROM order_seller_summary AS s
LEFT JOIN order_analytics AS o
    ON s.order_id = o.order_id;
-- summarize order-seller analytics
SELECT
    COUNT(*) AS order_seller_pairs,
    COUNT(DISTINCT order_id) AS distinct_orders,
    SUM(merchandise_value) AS merchandise_total,
    SUM(freight_value) AS freight_total
FROM order_seller_analytics;

-- calculate delivery reliability per seller
SELECT
    seller_id,
    COUNT(*) AS orders_with_items,
    COUNT(is_late) AS eligible_delivery_orders,
    SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN is_late THEN merchandise_value ELSE 0 END) AS merchandise_value_on_late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_late THEN 1 ELSE 0 END) / NULLIF(COUNT(is_late), 0),
        2
    ) AS late_delivery_percentage
FROM order_seller_analytics
GROUP BY seller_id
HAVING COUNT(is_late) >= 100
ORDER BY 
    1.0 * SUM(CASE WHEN is_late THEN 1 ELSE 0 END) / NULLIF(COUNT(is_late), 0) DESC,
    eligible_delivery_orders DESC,
    seller_id
LIMIT 5;

-- Which sellers have the most late orders
SELECT
    seller_id,
    COUNT(*) AS orders_with_items,
    COUNT(is_late) AS eligible_delivery_orders,
    SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN is_late THEN merchandise_value ELSE 0 END) AS merchandise_value_on_late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_late THEN 1 ELSE 0 END) / NULLIF(COUNT(is_late), 0),
        2
    ) AS late_delivery_percentage
FROM order_seller_analytics
GROUP BY seller_id
HAVING COUNT(is_late) >= 100
ORDER BY 
    late_orders DESC,
    merchandise_value_on_late_orders DESC,
    seller_id
LIMIT 5;


-- How much multi-seller orders affect
-- Sensitivity check: restrict to single-seller orders.
-- Require at least 100 eligible deliveries within this subset.
-- Delivery outcomes still do not establish seller responsibility.
SELECT
    seller_id,
    COUNT(*) AS orders_with_items,
    COUNT(is_late) AS eligible_delivery_orders,
    SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN is_late THEN merchandise_value ELSE 0 END) AS merchandise_value_on_late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN is_late THEN 1 ELSE 0 END) / NULLIF(COUNT(is_late), 0),
        2
    ) AS late_delivery_percentage
FROM order_seller_analytics
WHERE seller_count = 1
GROUP BY seller_id
HAVING COUNT(is_late) >= 100
ORDER BY 
    late_orders DESC,
    merchandise_value_on_late_orders DESC,
    seller_id
LIMIT 5;
