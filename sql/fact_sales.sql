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
    _source_system VARCHAR(50),
    _batch_id VARCHAR(100),
    _ingested_at TIMESTAMP
);