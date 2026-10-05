CREATE TABLE bronze.source_product (
    id VARCHAR(100),
    sku_name VARCHAR(255),
    category_code VARCHAR(100),
    category_id INT,
    brand VARCHAR(100),
    base_price FLOAT,
    current_price FLOAT,
    popularity_index FLOAT,
    launch_date BIGINT,
    discontinued_date BIGINT,
    is_active BOOLEAN,
    source_system VARCHAR(50),
    ingested_at DATE NOT NULL,

    CONSTRAINT pk_product PRIMARY KEY (id, ingested_at)
)
    PARTITION BY RANGE (ingested_at);