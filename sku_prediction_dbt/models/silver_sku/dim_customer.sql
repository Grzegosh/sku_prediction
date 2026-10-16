WITH _source AS (

SELECT
	*
	,ROW_NUMBER() OVER (PARTITION BY id, city ORDER BY ingested_at ASC) AS rnk_
FROM
	{{ source('sku_prediction', 'customer') }}

)

SELECT
	id
	,CAST(registration_date AS DATE)
	,segment
	,city
	,CAST(ingested_at AS DATE) AS valid_from
	,COALESCE(
		LEAD(ingested_at) OVER (PARTITION BY id ORDER BY ingested_at) - 1
		, DATE '9999-12-31'
	) AS valid_to
FROM
	_source
WHERE
	rnk_ = 1 
