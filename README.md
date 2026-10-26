# sku_prediction

Multi-level **revenue forecasting** with seasonality decomposition for a militaria / tactical-gear retailer.
The goal is to forecast sales **value (PLN)** at **SKU x sales channel** level (web / marketplace / physical store),
and to compare statistical and ML approaches (baselines, SARIMAX / ETS / Prophet, LightGBM).

The data is **synthetic** (about 200 SKUs in 8 categories, daily history 2021-01-01 to 2025-12-31) and was built to look like
exports from several source systems, including deliberate data-quality problems. The data engineering part
(bronze -> silver -> gold) is done by hand in Postgres with dbt; modelling comes next.

## Architecture

```
Parquet files (Hive partitions: ingestion_date=YYYY-MM-DD)
        |  python/ (main.py -> SQL.setup_pipeline)
        v
Postgres, schema bronze_sku   raw, as received (source_category / customer / date / product / sales)
        |  dbt Core
        v
Postgres, schema silver_sku   cleaned, deduplicated, SCD2 dimensions, calendar objects
        |  dbt Core
        v
Postgres, schema gold_sku     modelling tables (dense daily series, aggregates, calendar features)
        |
        v
notebooks (EDA, decomposition, modelling)   <- next stage
```

## Layers

**Bronze** - Parquet loaded as-is into `bronze_sku`. Source tables: category, customer (monthly snapshots), date (yearly batches),
product (monthly snapshots), sales (order lines, monthly batches). The raw data contains mixed price formats, two date formats,
dirty SKU keys, several representations of "guest" customers, duplicated rows and late-arriving corrections.

**Silver** (`models/silver_sku`):

| model | what it does |
|---|---|
| `dim_category` | product categories |
| `dim_product` | SCD Type 2 built from monthly snapshots (`valid_from`, `valid_to`, capped at the discontinuation date) |
| `dim_customer` | SCD Type 2 built from monthly snapshots (city changes) |
| `dim_date` | calendar attributes, holiday / commercial-event flags and names, days to the next and since the last holiday / special day, payday window |
| `dim_holiday`, `dim_special_day` | official holidays and commercial events (one row per date) |
| `dim_discount` | promotion calendar: `is_discount_period` and `discount_rate` per date |
| `fact_weather` | daily temperature (treated as a weather **forecast**, see limitations) |
| `fact_sales` | order lines: keys normalised, duplicates removed, `revenue = quantity x unit_price` |

Key decisions in `fact_sales`: per `(order_id, order_line_id)` the **earliest** ingested record is kept (late corrections are
intentionally ignored for this project); the source column `line_revenue` is not used, revenue is recomputed; stockout attempts
(`is_stockout_attempt`) are kept as censored demand.

**Gold** (`models/gold_sku`):

- `fact_sales_agg_daily_sku_channel` - dense series for every date x SKU x channel inside the SKU's active window
  (`launch_date` <= date <= last day before `discontinued_date`), zero-filled; columns `units_sold`, `revenue`,
  `stockout_attempts`, `stockout_units` (so a zero caused by a stockout can be told apart from zero demand).
- Aggregate views built from it: `fact_sales_agg_daily_sku`, `fact_sales_agg_daily_channel`, `fact_sales_agg_daily`.
- Calendar feature table, one row per date up to 2027-12-31 (calendar, holiday / event distances, payday window,
  promotion flag and depth, temperature forecast). *In progress.*

dbt tests cover keys, uniqueness, not-null and relationships between the date objects and `dim_date`.

## Reference numbers (for checking a rebuild)

| check | value |
|---|---|
| deduplicated order lines in `silver_sku.fact_sales` | 802,738 (799,063 sales + 3,675 stockout attempts) |
| `gold_sku.fact_sales_agg_daily_sku_channel` rows | 1,020,438 (340,146 date x SKU pairs x 3 channels) |
| total revenue in gold | 644,115,980.27 PLN |
| total units in gold | 1,222,403 |
| stockout attempts in gold | 3,674 |
| `dim_date` rows | 2,556 (2021-01-01 to 2027-12-31) |
| promotion days | 245 (35 per year, 2021-2027) |

## Known limitations of the data

These are known and deliberately left as they are; they matter when interpreting EDA and model results.

1. **Day/month swap in the loader.** Dates in the European format (`dd/mm/yyyy`) are parsed with `format='mixed'`, which reads
   ambiguous values month-first. About 29.6k order lines (about 3.7% of sales) end up on the wrong date. As a result 254 lines
   (about 189k PLN, about 0.03% of revenue, one stockout attempt) fall outside their SKU's active window and are missing
   from gold, and part of the daily signal is slightly blurred (weekly pattern, single-day effects).
2. **No effect of official holidays in sales.** A bug in the generator means the holiday uplift was applied only on commercial-event
   days, so official holidays (apart from 1 and 3 May, which coincide with an event) show no effect in the data.
3. **Temperature is a perfect forecast.** `fact_weather` is treated as a weather forecast known in advance and is also the value
   that drove the synthetic demand, so backtests that use it are optimistic. Values for 2026-2027 are generated with the same process.
4. **Channel is random.** Sales channels were assigned at random (about 62 / 28 / 10%), without their own seasonality, so a forecast
   per channel adds little beyond each channel's share of the total.
5. **Promotions are reconstructed.** The source has no promotion calendar; promotion days are derived from the discount observed
   on order lines (days where most lines are discounted) and extended to 2026-2027 by rule: 2-15 January (20%),
   1-14 July (15%) and the 7 days ending on Black Friday (30%).
6. **Price history is not reflected in sales prices.** Price changes in `dim_product` (SCD2) do not feed into the transaction prices.

## Repository layout

```
main.py                 entry point: creates dev / prod databases, schemas, bronze tables and loads the data
config.yaml             database connection and SQL script locations
python/                 loader (config_module.py, sql_module.py)
sql/                    DDL of the bronze tables and databases
data/                   source Parquet files (Hive partitions)
sku_prediction_dbt/     dbt project (models/silver_sku, models/gold_sku, macros, schema.yml)
```

## How to run

1. `pip install -r requirements.txt` (Python 3.12). dbt Core and the Postgres adapter are required as well
   (`dbt-core`, `dbt-postgres`; not listed in `requirements.txt` yet).
2. Set the Postgres connection in `config.yaml` and the dbt profile used by `sku_prediction_dbt/dbt_project.yml`.
3. `python main.py` creates the databases and bronze tables and loads the Parquet files.
4. `cd sku_prediction_dbt && dbt deps && dbt build` builds silver and gold and runs the tests.

