-- Select one review per order: latest review_answer_timestamp.
-- Break timestamp ties using review_id ASC.
-- Keep orders without reviews through a LEFT JOIN.

-- 1. Preview the first few rows of the review dataset
DESCRIBE
SELECT *
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv');

-- 2. Compare review rows with distinct reviewed orders
SELECT
    COUNT(*) AS review_rows,
    COUNT(DISTINCT order_id) AS reviewed_orders
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv');

-- 3. Find the distribution
WITH reviews_per_order AS (
    SELECT
        order_id,
        COUNT(*) AS review_count
    FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
    GROUP BY order_id
)
SELECT
    review_count,
    COUNT(*) AS order_count
FROM reviews_per_order
GROUP BY review_count
ORDER BY review_count;

-- 4. Inspect review order
WITH multiple_review_orders AS (
    SELECT order_id
    FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
    GROUP BY order_id
    HAVING COUNT(*) > 1
)
SELECT
    order_id,
    review_id,
    review_score,
    review_creation_date,
    review_answer_timestamp
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
WHERE order_id IN (
    SELECT order_id FROM multiple_review_orders
)
ORDER BY order_id, review_answer_timestamp, review_id
LIMIT 3;

-- 5. Count how many orders have conflicting scores.
SELECT
    order_id,
    COUNT(*) AS review_count,
    COUNT(DISTINCT review_score) AS distinct_scores
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
GROUP BY order_id
HAVING COUNT(DISTINCT review_score) > 1
ORDER BY order_id
LIMIT 3;

-- 6. Count all orders with conflicting scores by wrapping
WITH conflicting_reviews AS (
    SELECT
        order_id,
        COUNT(*) AS review_count,
        COUNT(DISTINCT review_score) AS distinct_scores
    FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
    GROUP BY order_id
    HAVING COUNT(DISTINCT review_score) > 1
)
SELECT COUNT(*) AS orders_with_conflicting_scores
FROM conflicting_reviews;

-- 7. Check missing values
SELECT
    COUNT(*) AS review_rows,
    COUNT(*) - COUNT(review_id) AS missing_review_ids,
    COUNT(*) - COUNT(order_id) AS missing_order_ids,
    COUNT(*) - COUNT(review_score) AS missing_scores,
    COUNT(*) - COUNT(review_creation_date) AS missing_creation_dates,
    COUNT(*) - COUNT(review_answer_timestamp) AS missing_answer_timestamps
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv');

-- 8. Check the score distribution
SELECT
    review_score,
    COUNT(*) AS review_rows
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
GROUP BY review_score
ORDER BY review_score;

-- 9. Check timestamp consistency: are any answers dated before their review's creation?
SELECT
    COUNT(*) AS answers_before_creation
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
WHERE review_answer_timestamp < review_creation_date;

-- 10. Check whether review_id is unique
SELECT
    review_id,
    COUNT(*) AS review_rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY review_rows DESC, review_id
LIMIT 5;

-- 11. Check whether the pair (order_id, review_id) is unique
SELECT
    order_id,
    review_id,
    COUNT(*) AS review_rows
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv')
GROUP BY order_id, review_id
HAVING COUNT(*) > 1
ORDER BY review_rows DESC, order_id, review_id;

-- 12. Ranking reviews within each order
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
-- WHERE order_id = '0035246a40f520710769010f752e7507'
LIMIT 5;

-- 13. Rank reviews count one review per reviewed order
WITH ranked_reviews AS (
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
)
SELECT
    COUNT(*) AS selected_review_rows,
    COUNT(DISTINCT order_id) AS reviewed_orders
FROM ranked_reviews
WHERE review_rank = 1;

-- 14. Check whether any review records refer to an order absent from the orders table
SELECT
    COUNT(*) AS orphan_review_rows,
    COUNT(DISTINCT r.order_id) AS orphan_review_orders
FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv') r
WHERE NOT EXISTS (
    SELECT 1
    FROM read_csv_auto('data/raw/olist_orders_dataset.csv') AS o
    WHERE o.order_id = r.order_id
);

-- 15. Check orders without any reviews
SELECT
    o.order_status,
    COUNT(*) AS orders_without_reviews
FROM read_csv_auto('data/raw/olist_orders_dataset.csv') AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv') AS r
    WHERE r.order_id = o.order_id
)
GROUP BY o.order_status
ORDER BY orders_without_reviews DESC;

-- 16. Final join check: does joining our selected reviews preserve every order exactly once?
WITH ranked_reviews AS (
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
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT o.order_id) AS distinct_orders,
    COUNT(r.order_id) AS orders_with_reviews,
    COUNT(*) - COUNT(r.order_id) AS orders_without_reviews
FROM read_csv_auto('data/raw/olist_orders_dataset.csv') AS o
LEFT JOIN selected_reviews AS r
    ON o.order_id = r.order_id;