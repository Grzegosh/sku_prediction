CREATE TABLE bronze.source_sales (
    order_id VARCHAR(50),
    order_line_id INT,
    sku_id_raw VARCHAR(50),
    customer_id_raw VARCHAR(100),
    order_ts_raw TIMESTAMP,
    quantity FLOAT,
    unit_price_raw FLOAT,
    discount_pct_raw FLOAT,
    line_revenue FLOAT,
    channel VARCHAR(250),
    order_status VARCHAR(50),
    is_stockout_attempt BOOLEAN,
    source_system VARCHAR(50),
    batch_id VARCHAR(100),
    ingested_at DATE NOT NULL,

    CONSTRAINT pk_order_id PRIMARY KEY (order_id, ingested_at)
)
PARTITION BY RANGE (ingested_at);