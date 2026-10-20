{{
    config(
        materialized = 'view'
    )
}}

SELECT
	date
	,sku_id
	,SUM(units_sold) AS units_sold
	,SUM(revenue) AS revenue
	,SUM(stockout_attempts) AS stockout_attempts
	,SUM(stockout_units) AS stockout_units
FROM
	{{ ref('fact_sales_agg_daily_sku_channel') }}
GROUP BY
	date
	,sku_id