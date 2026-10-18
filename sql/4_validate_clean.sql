-- @statement clean_summary
SELECT COUNT(*) AS n_rows,
       COUNT(DISTINCT id) AS unique_property_ids,
       COUNT(DISTINCT source_row) AS unique_source_rows,
       COUNT(*) FILTER (WHERE bedrooms IS NULL) AS bedrooms_null,
       COUNT(*) FILTER (WHERE yr_built IS NULL) AS yr_built_null,
       COUNT(*) FILTER (WHERE yr_renovated IS NULL) AS yr_renovated_null,
       COUNT(*) FILTER (WHERE house_age_at_sale_years IS NULL) AS house_age_null,
       COUNT(*) FILTER (WHERE was_renovated IS NULL) AS was_renovated_null,
       COUNT(*) FILTER (WHERE years_since_renovation IS NULL) AS years_since_renovation_null,
       COUNT(*) FILTER (WHERE house_age_at_sale_years < 0) AS negative_house_age,
       COUNT(*) FILTER (WHERE years_since_renovation < 0) AS negative_renovation_age
FROM staging.clean_property_sales;

-- @statement unexpected_identity_changes
SELECT t.source_row, t.id AS raw_id, c.id AS clean_id
FROM staging.typed_property_sales AS t
FULL JOIN staging.clean_property_sales AS c ON t.row_id = c.row_id
WHERE t.row_id IS NULL OR c.row_id IS NULL
   OR t.source_sha256 IS DISTINCT FROM c.source_sha256
   OR t.source_row IS DISTINCT FROM c.source_row
   OR t.id IS DISTINCT FROM c.id
   OR t.date IS DISTINCT FROM c.date
   OR t.price IS DISTINCT FROM c.price
   OR t.bedrooms IS DISTINCT FROM c.bedrooms_raw
   OR t.yr_built IS DISTINCT FROM c.yr_built_raw
   OR t.yr_renovated IS DISTINCT FROM c.yr_renovated_raw
ORDER BY t.source_row
LIMIT 20;

-- @statement review_cleaned_bedrooms
SELECT source_row, id, date, bedrooms_raw, bedrooms, bedrooms_unverified, sqft_living
FROM staging.clean_property_sales
WHERE bedrooms_unverified
ORDER BY source_row;