WITH base AS (
    SELECT
        order_id
        ,order_line_id
        ,UPPER(TRIM(E'\t\n\r ' FROM sku_id_raw)) AS sku_id
        ,UPPER(TRIM(E'\t\n\r ' FROM customer_id_raw)) AS customer_id_raw
        ,CAST(order_ts_raw AS DATE) AS order_date
        ,quantity
        ,unit_price_raw
        ,discount_pct_raw
        ,line_revenue
        ,order_status
        ,is_stockout_attempt
        ,UPPER(TRIM(channel)) AS channel
        ,ROW_NUMBER() OVER (
            PARTITION BY order_id, order_line_id
            ORDER BY _ingested_at ASC
        ) AS _rnk
    FROM {{ source('sku_prediction', 'sales') }}
),

deduped AS (
    SELECT * FROM base WHERE _rnk = 1
)

SELECT
    order_id
    ,order_line_id
    ,sku_id
    ,CASE
        WHEN customer_id_raw IS NULL OR customer_id_raw IN ('', 'NULL', 'GUEST')
            THEN 'GUEST'
        ELSE customer_id_raw
    END AS customer_id
    ,order_date
    ,quantity
    ,unit_price_raw AS unit_price
    ,discount_pct_raw / 100.0 AS discount_rate
    ,ROUND(CAST(quantity * unit_price_raw AS DECIMAL),2 ) AS revenue
    ,order_status
    ,is_stockout_attempt
    ,UPPER(TRIM(channel)) AS channel
FROM deduped