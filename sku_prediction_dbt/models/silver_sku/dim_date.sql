WITH _date AS (
    SELECT
        *
    FROM
        {{ source('sku_prediction', 'date') }}
)

SELECT
    *
FROM
    _date