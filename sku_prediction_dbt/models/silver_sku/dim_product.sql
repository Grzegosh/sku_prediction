WITH versions AS (
    SELECT
        id AS sku_id
        ,sku_name
        ,category_id
        ,brand
        ,current_price
        ,CAST(discontinued_date AS DATE) AS discontinued_date
        ,CAST(ingested_at AS DATE) AS valid_from
        ,ROW_NUMBER() OVER (
            PARTITION BY id, brand, category_id, current_price
            ORDER BY ingested_at
        ) AS _rnk
    FROM {{ source('sku_prediction', 'product') }}
),

first_transform AS (
    SELECT
        *
        ,COALESCE(
            LEAD(valid_from) OVER (PARTITION BY sku_id ORDER BY valid_from) - 1,
            DATE '9999-12-31'
        ) AS valid_to
    FROM versions
    WHERE _rnk = 1
)

SELECT
    sku_id
    ,sku_name
    ,category_id
    ,brand
    ,current_price
    ,discontinued_date
    ,valid_from
    ,LEAST(valid_to, discontinued_date - 1) AS valid_to
FROM first_transform
WHERE discontinued_date IS NULL
   OR valid_from < discontinued_date