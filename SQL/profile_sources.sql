SELECT
    COUNT(*) AS item_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT seller_id) AS distinct_sellers
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv');

-- Orders without matching item records, grouped by status.
SELECT
    o.order_status,
    COUNT(*) AS orders_without_items
FROM read_csv_auto('data/raw/olist_orders_dataset.csv') AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM read_csv_auto('data/raw/olist_order_items_dataset.csv') AS i
    WHERE i.order_id = o.order_id   
)
GROUP BY o.order_status
ORDER BY orders_without_items DESC;

-- Item records whose order_id is absent from the orders table.
SELECT
    COUNT(*) AS orphan_item_rows,
    COUNT(DISTINCT i.order_id) AS orphan_order_ids
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv') AS i
WHERE NOT EXISTS (
    SELECT 1
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv') AS o
    WHERE o.order_id = i.order_id
);

-- Find duplicate order-item keys
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS row_count
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC;

-- Check for missing values in the item key.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(order_id) AS missing_order_ids,
    COUNT(*) - COUNT(order_item_id) AS missing_order_item_ids
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv');

-- Summarize each order's items.
SELECT
    order_id,
    COUNT(*) AS item_count,
    COUNT(DISTINCT seller_id) AS seller_count,
    SUM(CAST(price AS DECIMAL(18,2))) AS merchandise_value,
    SUM(CAST(freight_value AS DECIMAL(18,2))) AS freight_value
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
GROUP BY order_id
ORDER BY item_count DESC, order_id
LIMIT 10;

-- Orders with multiple sellers.
SELECT
    order_id,
    COUNT(*) AS item_count,
    COUNT(DISTINCT seller_id) AS seller_count
FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
GROUP BY order_id
HAVING COUNT(DISTINCT seller_id) > 1
ORDER BY seller_count DESC, order_id
LIMIT 10;

-- Count orders by their number of sellers.
WITH order_summary AS (
    SELECT
        order_id,
        COUNT(DISTINCT seller_id) AS seller_count
    FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
    GROUP BY order_id
)
SELECT
    seller_count,
    COUNT(*) AS order_count
FROM order_summary
GROUP BY seller_count
ORDER BY seller_count;

-- join item summaries
WITH order_summary AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM read_csv_auto('data/raw/olist_order_items_dataset.csv')
    GROUP BY order_id
)
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT o.order_id) AS distinct_orders,
    COUNT(s.order_id) AS orders_with_items,
    COUNT(*) - COUNT(s.order_id) AS orders_without_items
FROM read_csv_auto('data/raw/olist_orders_dataset.csv') AS o
LEFT JOIN order_summary AS s
    ON o.order_id = s.order_id;

-- -- Count orders by their number of payment records.
-- WITH payment_summary AS (
--     SELECT
--         order_id,
--         COUNT(*) AS payment_record_count
--     FROM read_csv_auto('data/raw/olist_order_payments_dataset.csv')
--     GROUP BY order_id
-- )
-- SELECT
--     payment_record_count,
--     COUNT(*) AS order_count
-- FROM payment_summary
-- GROUP BY payment_record_count
-- ORDER BY payment_record_count;
