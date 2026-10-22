WITH _dates AS (

SELECT
	*
FROM
	{{ ref('dim_date') }}

), black_friday_range AS (

SELECT
	ss.date_from
	,d.date AS date_to
FROM
	_dates d
JOIN LATERAL
	(SELECT
		dd.date
		,dd.date - 6 AS date_from
	FROM
		{{ ref('dim_date') }} dd
	WHERE
		commercial_event_name = 'Black Friday'
	) ss
ON
	d.date = ss.date

), count_per_date AS (

SELECT
	order_date
	,COUNT(*) AS total_lines_count
FROM
	{{ ref('fact_sales') }}
GROUP BY
	order_date

), lines_with_promo AS (

SELECT
	order_date
	,COUNT(*) AS promo_lines_count
FROM
	{{ ref('fact_sales') }}
WHERE
	discount_rate > 0
GROUP BY
	order_date

), result AS (

SELECT
	cpd.order_date
	,cpd.total_lines_count
	,ROUND(lwp.promo_lines_count * 1.0 / cpd.total_lines_count * 1.0,3) AS test
FROM
	count_per_date cpd
LEFT JOIN
	lines_with_promo lwp
ON
	cpd.order_date = lwp.order_date

), dates_to_highlight_present AS (

SELECT
	r.order_date
FROM
	result r
WHERE
	test > 0.5
	AND EXTRACT(MONTH FROM r.order_date) != 11

), dates_to_highlight_future AS (

-- reguła dla dat po ostatniej dacie sprzedaży (u nas 2026-2027):
-- stały blok 2-15 stycznia i 1-14 lipca; okno Black Friday liczy black_friday_range
SELECT
	d.date AS order_date
FROM
	_dates d
WHERE
	d.date > (SELECT MAX(order_date) FROM {{ ref('fact_sales') }})
	AND (
		(EXTRACT(MONTH FROM d.date) = 1 AND EXTRACT(DAY FROM d.date) BETWEEN 2 AND 15)
		OR
		(EXTRACT(MONTH FROM d.date) = 7 AND EXTRACT(DAY FROM d.date) BETWEEN 1 AND 14)
	)

), dates_to_highlight AS (

SELECT order_date FROM dates_to_highlight_present
UNION
SELECT order_date FROM dates_to_highlight_future

)

SELECT
	d.date
	,CASE
		WHEN doh.order_date IS NOT NULL OR dfr.date_from IS NOT NULL THEN 1
		ELSE 0
	END AS is_discount_period
FROM
	_dates d
LEFT JOIN
	dates_to_highlight doh
ON
	d.date = doh.order_date
LEFT JOIN
	black_friday_range dfr
ON
	d.date BETWEEN dfr.date_from AND dfr.date_to
ORDER BY
	d.date ASC