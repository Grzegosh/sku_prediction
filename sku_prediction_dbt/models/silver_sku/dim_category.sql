WITH _source AS (
SELECT
	*
FROM
	{{ source('sku_prediction', 'category') }}
)
SELECT
	category_id AS id
	,category_name
	,category_group
FROM
	_source
WHERE
	category_id IS NOT NULL