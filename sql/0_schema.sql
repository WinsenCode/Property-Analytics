-- @statement create_raw_schema
CREATE SCHEMA IF NOT EXISTS raw;

-- @statement create_staging_schema
CREATE SCHEMA IF NOT EXISTS staging;

-- @statement create_analytics_schema
CREATE SCHEMA IF NOT EXISTS analytics;

-- @statement create_ingestion_log
CREATE TABLE IF NOT EXISTS raw.ingestion_log (
    source_sha256 text PRIMARY KEY CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
    source_file_name text NOT NULL,
    row_count integer NOT NULL CHECK (row_count > 0),
    imported_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- @statement create_raw_table
-- Raw source fields remain TEXT: preserve the imported cell contents.
-- row_id is a database row key; id is the property identifier.
CREATE TABLE IF NOT EXISTS raw.raw_property_sales (
    row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_sha256 text NOT NULL REFERENCES raw.ingestion_log(source_sha256),
    source_row integer NOT NULL CHECK (source_row > 0),
    "id" text,
    "date" text,
    "price" text,
    "bedrooms" text,
    "bathrooms" text,
    "sqft_living" text,
    "sqft_lot" text,
    "floors" text,
    "waterfront" text,
    "view" text,
    "condition" text,
    "grade" text,
    "sqft_above" text,
    "sqft_basement" text,
    "yr_built" text,
    "yr_renovated" text,
    "zipcode" text,
    "lat" text,
    "long" text,
    "sqft_living15" text,
    "sqft_lot15" text,
    UNIQUE (source_sha256, source_row)
);

-- @statement create_typed_view
-- This view changes types only. It does not clean anomalies or discard rows.
-- Query it only after raw format checks pass. make_date rejects invalid dates.
-- Contract for this dataset: YYYYMMDDT000000, with no time-of-day information.
CREATE OR REPLACE VIEW staging.typed_property_sales AS
SELECT
    r.row_id,
    r.source_sha256, 
    r.source_row,
    r."id",
    make_date(
        substring(r."date" FROM 1 FOR 4)::integer,
        substring(r."date" FROM 5 FOR 2)::integer,
        substring(r."date" FROM 7 FOR 2)::integer
    ) AS "date",
    r."price"::double precision AS "price",
    r."bedrooms"::integer AS "bedrooms",
    r."bathrooms"::double precision AS "bathrooms",
    r."sqft_living"::integer AS "sqft_living",
    r."sqft_lot"::integer AS "sqft_lot",
    r."floors"::double precision AS "floors",
    r."waterfront"::integer AS "waterfront",
    r."view"::integer AS "view",
    r."condition"::integer AS "condition",
    r."grade"::integer AS "grade",
    r."sqft_above"::integer AS "sqft_above",
    r."sqft_basement"::integer AS "sqft_basement",
    r."yr_built"::integer AS "yr_built",
    r."yr_renovated"::integer AS "yr_renovated",
    r."zipcode",
    r."lat"::double precision AS "lat",
    r."long"::double precision AS "long",
    r."sqft_living15"::integer AS "sqft_living15",
    r."sqft_lot15"::integer AS "sqft_lot15"
FROM raw.raw_property_sales AS r;