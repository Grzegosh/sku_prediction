WITH _source AS (
SELECT
	CAST(s.date AS DATE) AS date
	,s.weekday
	,s.is_weekend
	,s.day_of_year
	,s.official_holiday_name
	,s.is_commercial_event
    ,dh.holiday_name
	,s.commercial_event_name
	,s.is_payday_window
FROM
	{{ source('sku_prediction', 'date') }} s
LEFT JOIN
    {{ ref('dim_holiday') }} dh
ON
    s.date = dh.date

), _first_trans AS (
SELECT
	date
	,CAST(EXTRACT(isoyear FROM date) AS INT) AS iso_year
	,CAST(EXTRACT(month FROM date) AS INT) AS month
	,TO_CHAR(date, 'FMMonth') AS month_name
	,EXTRACT(isodow FROM date) AS iso_day_of_week
	,TO_CHAR(date, 'FMDay') AS day_name
	,CAST(EXTRACT(day FROM date) AS INT) AS day_of_month
	,CAST(DATE_PART('doy', date) AS INT) AS day_of_year
    ,CAST(EXTRACT(quarter FROM date) AS INT) AS quarter
	,CAST(EXTRACT(week FROM date) AS INT) AS iso_week_of_year
    ,CASE
        WHEN holiday_name IS NULL THEN 0
        ELSE 1 
    END AS is_holiday
    ,holiday_name
	,CASE
		WHEN commercial_event_name IS NOT NULL THEN 1 
		ELSE 0
	END AS is_commercial_event
	,commercial_event_name
	,is_payday_window
    ,is_weekend
FROM
	_source s

), calc_min_date_to_holiday AS (
SELECT
    ft.date AS base_date
    ,MIN(dh.date) AS next_holiday
FROM
    _first_trans ft
LEFT JOIN
    {{ ref('dim_holiday') }} dh
ON
    ft.date <= dh.date
GROUP BY
    ft.date

), calc_days_to_holiday AS (

SELECT
    base_date
    ,ABS(base_date - next_holiday) as next_holiday_in
FROM
    calc_min_date_to_holiday

), calc_min_date_to_special_day AS (
SELECT
    ft.date AS base_date
    ,MIN(dsd.date) AS next_special_day
FROM
    _first_trans ft
LEFT JOIN
    {{ ref('dim_special_day') }} dsd
ON
    ft.date <= dsd.date
GROUP BY
    ft.date

), calc_days_to_special_day AS (

SELECT
    base_date
    ,ABS(base_date - next_special_day) as next_special_day_in
FROM
    calc_min_date_to_special_day
)
SELECT
    ft.date
    ,ft.iso_year
    ,ft.quarter
    ,ft.month
    ,ft.month_name
    ,ft.iso_day_of_week
    ,ft.day_of_year
    ,ft.day_name
    ,ft.day_of_month
    ,ft.iso_week_of_year
    ,ft.is_holiday
    ,ft.is_weekend
    ,ft.holiday_name
    ,cdth.next_holiday_in
    ,ft.is_commercial_event
    ,ft.commercial_event_name
    ,cdtsd.next_special_day_in
    ,ft.is_payday_window
FROM
    _first_trans ft
LEFT JOIN
    calc_days_to_holiday cdth
ON
    ft.date = cdth.base_date
LEFT JOIN
    calc_days_to_special_day cdtsd
ON
    ft.date = cdtsd.base_date