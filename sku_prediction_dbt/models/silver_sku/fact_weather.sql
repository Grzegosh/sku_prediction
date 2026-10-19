WITH _source AS (
SELECT
	CAST(date AS DATE) AS date
	,temperature_c
FROM
	{{ source('sku_prediction', 'date') }}
)
SELECT
	*
FROM
	_source
