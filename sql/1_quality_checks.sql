-- @statement raw_profile
SELECT COUNT(*) AS n_rows,
    COUNT(DISTINCT id) AS unique_property_ids,
    COUNT(DISTINCT zipcode) AS unique_zipcodes,
    COUNT(DISTINCT source_sha256) AS source_files,
    MIN(source_row) AS first_source_row,
    MAX(source_row) AS last_source_row
FROM raw.raw_property_sales;

-- @statement raw_missing
-- LATERAL VALUES unpivots source columns so every column is checked.
SELECT v.column_name,
    COUNT(*) FILTER (WHERE v.value IS NULL OR btrim(v.value) = '') AS missing_or_blank
FROM raw.raw_property_sales AS r
CROSS JOIN LATERAL (VALUES
    ('id', r."id"),
    ('date', r."date"),
    ('price', r."price"),
    ('bedrooms', r."bedrooms"),
    ('bathrooms', r."bathrooms"),
    ('sqft_living', r."sqft_living"),
    ('sqft_lot', r."sqft_lot"),
    ('floors', r."floors"),
    ('waterfront', r."waterfront"),
    ('view', r."view"),
    ('condition', r."condition"),
    ('grade', r."grade"),
    ('sqft_above', r."sqft_above"),
    ('sqft_basement', r."sqft_basement"),
    ('yr_built', r."yr_built"),
    ('yr_renovated', r."yr_renovated"),
    ('zipcode', r."zipcode"),
    ('lat', r."lat"),
    ('long', r."long"),
    ('sqft_living15', r."sqft_living15"),
    ('sqft_lot15', r."sqft_lot15")
) AS v(column_name, value)
GROUP BY v.column_name
ORDER BY v.column_name;

-- @statement raw_format_failures
-- Regex checks shape, not calendar validity or numeric type range.
-- Float fields allow scientific notation present in the audited CSV, e.g. 1.05E+06.
-- Casting through the typed view is a separate gate and fails loudly.
SELECT v.column_name, COUNT(*) AS invalid_rows
FROM raw.raw_property_sales AS r
CROSS JOIN LATERAL (VALUES
    ('id', r."id", '^[0-9]+$'),
    ('date', r."date", '^[0-9]{8}T000000$'),
    ('price', r."price", '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'),
    ('bedrooms', r."bedrooms", '^[+-]?[0-9]+$'),
    ('bathrooms', r."bathrooms", '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'),
    ('sqft_living', r."sqft_living", '^[+-]?[0-9]+$'),
    ('sqft_lot', r."sqft_lot", '^[+-]?[0-9]+$'),
    ('floors', r."floors", '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'),
    ('waterfront', r."waterfront", '^[+-]?[0-9]+$'),
    ('view', r."view", '^[+-]?[0-9]+$'),
    ('condition', r."condition", '^[+-]?[0-9]+$'),
    ('grade', r."grade", '^[+-]?[0-9]+$'),
    ('sqft_above', r."sqft_above", '^[+-]?[0-9]+$'),
    ('sqft_basement', r."sqft_basement", '^[+-]?[0-9]+$'),
    ('yr_built', r."yr_built", '^[+-]?[0-9]+$'),
    ('yr_renovated', r."yr_renovated", '^[+-]?[0-9]+$'),
    ('zipcode', r."zipcode", '^[0-9]{5}$'),
    ('lat', r."lat", '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'),
    ('long', r."long", '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$'),
    ('sqft_living15', r."sqft_living15", '^[+-]?[0-9]+$'),
    ('sqft_lot15', r."sqft_lot15", '^[+-]?[0-9]+$')
) AS v(column_name, value, pattern)
WHERE v.value IS NULL OR v.value !~ v.pattern
GROUP BY v.column_name
ORDER BY v.column_name;

-- @statement typed_profile
SELECT COUNT(*) AS n_rows,
    MIN(date) AS first_sale_date, MAX(date) AS last_sale_date,
    MIN(price) AS min_price_usd, MAX(price) AS max_price_usd,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median_price_usd
FROM staging.typed_property_sales;

-- @statement duplicates
WITH totals AS (SELECT COUNT(*) AS n FROM staging.typed_property_sales),
id_counts AS (SELECT id, COUNT(*) AS n FROM staging.typed_property_sales GROUP BY id),
full_distinct AS (SELECT DISTINCT "id", "date", "price", "bedrooms", "bathrooms", "sqft_living", "sqft_lot", "floors", "waterfront", "view", "condition", "grade", "sqft_above", "sqft_basement", "yr_built", "yr_renovated", "zipcode", "lat", "long", "sqft_living15", "sqft_lot15" FROM staging.typed_property_sales),
key_distinct AS (SELECT DISTINCT id, date FROM staging.typed_property_sales),
partial_distinct AS (SELECT DISTINCT "price", "bedrooms", "bathrooms", "sqft_living", "sqft_lot", "floors", "waterfront", "view", "condition", "grade", "sqft_above", "sqft_basement", "yr_built", "yr_renovated", "zipcode", "lat", "long", "sqft_living15", "sqft_lot15" FROM staging.typed_property_sales),
pair_distinct AS (SELECT DISTINCT price, sqft_living FROM staging.typed_property_sales)
SELECT
    (SELECT n FROM totals) - (SELECT COUNT(*) FROM full_distinct) AS full_row_duplicates,
    (SELECT COUNT(*) FROM id_counts) AS unique_property_ids,
    (SELECT COUNT(*) FROM id_counts WHERE n > 1) AS property_ids_seen_more_than_once,
    (SELECT n FROM totals) - (SELECT COUNT(*) FROM id_counts) AS extra_rows_after_first_id,
    (SELECT MAX(n) FROM id_counts) AS max_transactions_per_property,
    (SELECT n FROM totals) - (SELECT COUNT(*) FROM key_distinct) AS duplicate_id_date,
    (SELECT n FROM totals) - (SELECT COUNT(*) FROM partial_distinct) AS same_all_except_id_date,
    (SELECT n FROM totals) - (SELECT COUNT(*) FROM pair_distinct) AS same_price_and_living_area;

-- @statement domain_flags
SELECT 'id_missing_or_empty' AS check_name, COUNT(*) FILTER (WHERE id IS NULL OR btrim(id) = '') AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'zipcode_format_invalid' AS check_name, COUNT(*) FILTER (WHERE zipcode IS NULL OR zipcode !~ '^[0-9]{5}$') AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'price_nonpositive' AS check_name, COUNT(*) FILTER (WHERE price <= 0) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'living_nonpositive' AS check_name, COUNT(*) FILTER (WHERE sqft_living <= 0) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'lot_nonpositive' AS check_name, COUNT(*) FILTER (WHERE sqft_lot <= 0) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'bedrooms_zero_review' AS check_name, COUNT(*) FILTER (WHERE bedrooms = 0) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'bedrooms_negative' AS check_name, COUNT(*) FILTER (WHERE bedrooms < 0) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'bathrooms_zero_review' AS check_name, COUNT(*) FILTER (WHERE bathrooms = 0) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'bathrooms_negative' AS check_name, COUNT(*) FILTER (WHERE bathrooms < 0) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'waterfront_invalid' AS check_name, COUNT(*) FILTER (WHERE waterfront NOT IN (0, 1)) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'view_invalid' AS check_name, COUNT(*) FILTER (WHERE view NOT BETWEEN 0 AND 4) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'condition_invalid' AS check_name, COUNT(*) FILTER (WHERE condition NOT BETWEEN 1 AND 5) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'grade_invalid' AS check_name, COUNT(*) FILTER (WHERE grade NOT BETWEEN 1 AND 13) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'latitude_invalid' AS check_name, COUNT(*) FILTER (WHERE lat NOT BETWEEN -90 AND 90) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'longitude_invalid' AS check_name, COUNT(*) FILTER (WHERE long NOT BETWEEN -180 AND 180) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'living_area_mismatch' AS check_name, COUNT(*) FILTER (WHERE sqft_living <> sqft_above + sqft_basement) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'built_after_sale_year' AS check_name, COUNT(*) FILTER (WHERE yr_built > EXTRACT(YEAR FROM date)) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'renovated_after_sale_year' AS check_name, COUNT(*) FILTER (WHERE yr_renovated > EXTRACT(YEAR FROM date)) AS flagged_rows
FROM staging.typed_property_sales
UNION ALL
SELECT 'renovated_before_built' AS check_name, COUNT(*) FILTER (WHERE yr_renovated > 0 AND yr_renovated < yr_built) AS flagged_rows
FROM staging.typed_property_sales;

-- @statement bedroom_review
SELECT source_row, id, date, bedrooms, bathrooms, sqft_living, grade, price
FROM staging.typed_property_sales
WHERE bedrooms > 10
ORDER BY bedrooms DESC, source_row;

-- @statement year_review
SELECT source_row, id, date, yr_built, yr_renovated
FROM staging.typed_property_sales
WHERE yr_built > EXTRACT(YEAR FROM date)
    OR yr_renovated > EXTRACT(YEAR FROM date)
ORDER BY source_row;