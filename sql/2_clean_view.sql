-- @statement create_clean_view
-- Cleaning policy mirrors the audited Python notebook.
-- No imputation, target encoding, scaling, row deletion, or price capping.
CREATE OR REPLACE VIEW staging.clean_property_sales AS
WITH base AS (
    SELECT t.*, EXTRACT(YEAR FROM t.date)::integer AS sale_year
    FROM staging.typed_property_sales AS t
), masked AS (
    SELECT
        row_id, source_sha256, source_row,
        id, date, price,
        CASE WHEN bedrooms = 33 THEN NULL ELSE bedrooms END::double precision AS bedrooms,
        bathrooms, sqft_living, sqft_lot, floors, waterfront, view, condition, grade,
        sqft_above, sqft_basement,
        CASE WHEN yr_built > sale_year THEN NULL ELSE yr_built END::double precision AS yr_built,
        CASE WHEN yr_renovated > sale_year THEN NULL ELSE yr_renovated END::double precision AS yr_renovated,
        zipcode, lat, long, sqft_living15, sqft_lot15,
        bedrooms AS bedrooms_raw,
        bedrooms = 33 AS bedrooms_unverified,
        yr_built AS yr_built_raw,
        yr_renovated AS yr_renovated_raw,
        sale_year
    FROM base
)
SELECT
    row_id, source_sha256, source_row,
    id, date, price, bedrooms, bathrooms, sqft_living, sqft_lot, floors,
    waterfront, view, condition, grade, sqft_above, sqft_basement,
    yr_built, yr_renovated, zipcode, lat, long, sqft_living15, sqft_lot15,
    bedrooms_raw, bedrooms_unverified, yr_built_raw, yr_renovated_raw,
    (sale_year - yr_built)::double precision AS house_age_at_sale_years,
    CASE
        WHEN yr_renovated IS NULL THEN NULL
        WHEN yr_renovated > 0 THEN 1.0
        ELSE 0.0
    END::double precision AS was_renovated,
    CASE
        WHEN yr_renovated > 0 THEN sale_year - yr_renovated
        ELSE NULL
    END::double precision AS years_since_renovation
FROM masked;