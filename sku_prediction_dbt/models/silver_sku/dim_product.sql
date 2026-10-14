WITH _base AS (
SELECT
	*
	,ROW_NUMBER() OVER (PARTITION BY id, brand, base_price, current_price, popularity_index ORDER BY ingested_at ASC) AS _rnk
FROM
	{{ source('sku_prediction', 'product') }}
)
SELECT
	id
	,sku_name
	,category_id
	,brand
	,base_price
    ,current_price
	,popularity_index
	,CASE
		WHEN ingested_at < discontinued_date OR discontinued_date IS NULL THEN 1
		ELSE 0
	END AS is_active
	,CAST(discontinued_date AS DATE) AS discontinued_date
	,ingested_at AS valid_from
	,COALESCE(LEAD(ingested_at) OVER (PARTITION BY id, brand ORDER BY ingested_at), '9999-12-31') AS valid_to --fix
FROM
	_base
WHERE
	_rnk = 1 