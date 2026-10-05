CREATE TABLE bronze.source_category (
    category_id INT,
    category_code VARCHAR(50),
    category_name VARCHAR(100),
    category_group VARCHAR(50),
    source_system VARCHAR(50),
    ingested_at DATE NOT NULL,

    CONSTRAINT pk_category_id PRIMARY KEY (category_id, ingested_at)
) 
PARTITION BY RANGE (ingested_at);