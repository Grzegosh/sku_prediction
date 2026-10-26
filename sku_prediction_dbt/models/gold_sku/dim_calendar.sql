SELECT
	dd.date
	,ROW_NUMBER() OVER(ORDER BY dd.date ASC) AS days_since_start
	,dd.quarter
	,dd.month
	,dd.iso_day_of_week
	,dd.day_of_year
	,dd.day_of_month
	,dd.iso_week_of_year
	,dd.is_holiday
	,dd.holiday_name
	,dd.next_holiday_in
	,dd.days_since_last_holiday
	,dd.is_commercial_event AS is_special_day
	,dd.commercial_event_name
	,dd.next_special_day_in
	,dd.days_since_last_special_day
	,dd.is_payday_window
	,fw.temperature_c AS temperature_c_forecast
	,dis.is_discount_period
	,dis.discount_rate
FROM
	{{ ref('dim_date') }} dd
LEFT JOIN
	{{ ref('fact_weather') }} fw
ON
	dd.date = fw.date
LEFT JOIN
	{{ ref('dim_discount') }} dis
ON
	dd.date = dis.date