CREATE TABLE bronze.source_customer (
    id VARCHAR(50),
    registration_date BIGINT,
    segment VARCHAR(10),
    city VARCHAR(100),
    source_system VARCHAR(50),
    ingested_at DATE NOT NULL,

    CONSTRAINT pk_customer PRIMARY KEY (id, ingested_at)
)
PARTITION BY RANGE (ingested_at);