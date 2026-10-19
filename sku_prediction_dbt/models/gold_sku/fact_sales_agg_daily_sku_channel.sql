WITH _bounds AS (
    SELECT
        MIN(order_date) AS min_date
        ,MAX(order_date) AS max_date
    FROM {{ ref('fact_sales') }}
),

_agg AS (
    SELECT
        order_date
        ,sku_id
        ,channel
        ,SUM(quantity)  FILTER (WHERE is_stockout_attempt = false) AS units_sold
        ,SUM(revenue)   FILTER (WHERE is_stockout_attempt = false) AS revenue
        ,COUNT(*)       FILTER (WHERE is_stockout_attempt = true)  AS stockout_attempts
        ,SUM(quantity)  FILTER (WHERE is_stockout_attempt = true)  AS stockout_units
    FROM {{ ref('fact_sales') }}
    GROUP BY order_date, sku_id, channel
),

_channels AS (
    SELECT DISTINCT channel
    FROM {{ ref('fact_sales') }}
),

_siatka AS (
    SELECT
        dd.date
        ,dp.sku_id
        ,c.channel
    FROM {{ ref('dim_date') }} dd
    CROSS JOIN _bounds b
    JOIN {{ ref('dim_product') }} dp
        ON dd.date BETWEEN dp.valid_from AND dp.valid_to
        AND dd.date >= dp.launch_date
    CROSS JOIN _channels c
    WHERE dd.date BETWEEN b.min_date AND b.max_date
)

SELECT
    s.date
    ,s.sku_id
    ,s.channel
    ,COALESCE(a.units_sold, 0)        AS units_sold
    ,COALESCE(a.revenue, 0)           AS revenue
    ,COALESCE(a.stockout_attempts, 0) AS stockout_attempts
    ,COALESCE(a.stockout_units, 0)    AS stockout_units
FROM _siatka s
LEFT JOIN _agg a
    ON s.date = a.order_date
    AND s.sku_id = a.sku_id
    AND s.channel = a.channel