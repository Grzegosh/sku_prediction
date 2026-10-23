WITH _dates AS (

SELECT
	*
FROM
	{{ ref('dim_date') }}

), black_friday_range AS (

SELECT
	date - 6 AS date_from
	,date AS date_to
FROM
	_dates
WHERE
	commercial_event_name = 'Black Friday'

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
	,ROUND(lwp.promo_lines_count * 1.0 / cpd.total_lines_count, 3) AS test
FROM
	count_per_date cpd
LEFT JOIN
	lines_with_promo lwp
ON
	cpd.order_date = lwp.order_date

), dates_to_highlight_present AS (

SELECT
	order_date
FROM
	result
WHERE
	test > 0.5
	AND EXTRACT(MONTH FROM order_date) != 11

), dates_to_highlight_future AS (

-- reguła dla dat po ostatniej dacie sprzedaży (u nas 2026-2027):
-- stały blok 2-15 stycznia i 1-14 lipca; okno Black Friday liczy black_friday_range
SELECT
	date AS order_date
FROM
	_dates
WHERE
	date > (SELECT MAX(order_date) FROM {{ ref('fact_sales') }})
	AND (
		(EXTRACT(MONTH FROM date) = 1 AND EXTRACT(DAY FROM date) BETWEEN 2 AND 15)
		OR
		(EXTRACT(MONTH FROM date) = 7 AND EXTRACT(DAY FROM date) BETWEEN 1 AND 14)
	)

), dates_to_highlight AS (

SELECT order_date FROM dates_to_highlight_present
UNION
SELECT order_date FROM dates_to_highlight_future

), daily_mode AS (

-- dominanta rabatu w każdym dniu sprzedaży
SELECT
	order_date
	,MODE() WITHIN GROUP (ORDER BY discount_rate) AS discount_rate
FROM
	{{ ref('fact_sales') }}
GROUP BY
	order_date

), rate_per_month AS (

-- jeden rabat na miesiąc (styczeń, lipiec, listopad), z dni, w których dominanta jest różna od zera;
-- sprawdzone: w każdym z tych miesięcy jest dokładnie jedna taka wartość
SELECT
	CAST(EXTRACT(MONTH FROM order_date) AS INT) AS month_no
	,MAX(discount_rate) AS discount_rate
FROM
	daily_mode
WHERE
	discount_rate > 0
GROUP BY
	CAST(EXTRACT(MONTH FROM order_date) AS INT)

), flagged AS (

SELECT
	d.date
	,CAST(EXTRACT(MONTH FROM d.date) AS INT) AS month_no
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

)

SELECT
	f.date
	,f.is_discount_period
	,CASE
		WHEN f.is_discount_period = 1 THEN rpm.discount_rate
		ELSE 0
	END AS discount_rate
FROM
	flagged f
LEFT JOIN
	rate_per_month rpm
ON
	f.month_no = rpm.month_no
ORDER BY
	f.date