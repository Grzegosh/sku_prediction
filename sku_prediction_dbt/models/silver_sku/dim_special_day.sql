WITH _source AS (
SELECT
	CAST(date AS DATE) AS date
	,commercial_event_name AS special_day_name
FROM
	{{ source('sku_prediction', 'date') }}
)
SELECT
	date
	,special_day_name
FROM
	_source
WHERE
	special_day_name IS NOT NULL
