CREATE TABLE bronze.source_data (
    date BIGINT PRIMARY KEY,
    weekday VARCHAR(1) NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    day_of_year INT NOT NULL,
    is_official_holiday BOOLEAN NOT NULL,
    official_holiday_name VARCHAR(200),
    is_commercial_event BOOLEAN NOT NULL,
    commercial_event_name VARCHAR(200),
    is_payday_window BOOLEAN NOT NULL,
    temperature_c FLOAT,
    source_system VARCHAR(50),
    ingested_at BIGINT
);