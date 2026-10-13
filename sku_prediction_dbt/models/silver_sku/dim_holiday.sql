WITH _source AS (
SELECT
	CAST(date AS DATE) AS date
	,official_holiday_name AS holiday_name
FROM
	{{ source('sku_prediction', 'date') }}
)
SELECT
	date
	,holiday_name
FROM
	_source
WHERE
	holiday_name IS NOT NULL
ORDER BY
	date DESC
