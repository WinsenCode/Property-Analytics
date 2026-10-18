-- @statement create_zipcode_view
CREATE OR REPLACE VIEW analytics.sales_by_zipcode AS
SELECT zipcode, COUNT(*) AS sales_count,
       AVG(price) AS avg_price_usd,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median_price_usd
FROM staging.clean_property_sales
GROUP BY zipcode;

-- @statement create_monthly_view
CREATE OR REPLACE VIEW analytics.sales_by_month AS
WITH monthly AS (
    SELECT date_trunc('month', date)::date AS sale_month,
           COUNT(*) AS sales_count,
           MIN(date) AS first_observed, MAX(date) AS last_observed,
           AVG(price) AS avg_price_usd,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median_price_usd
    FROM staging.clean_property_sales
    GROUP BY date_trunc('month', date)::date
)
SELECT *,
       sale_month = MIN(sale_month) OVER ()
       OR sale_month = MAX(sale_month) OVER () AS is_boundary_month
FROM monthly;

-- @statement create_grade_view
CREATE OR REPLACE VIEW analytics.sales_by_grade AS
SELECT grade, COUNT(*) AS sales_count,
       AVG(price) AS avg_price_usd,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median_price_usd
FROM staging.clean_property_sales
GROUP BY grade;

-- @statement create_waterfront_view
CREATE OR REPLACE VIEW analytics.sales_by_waterfront AS
SELECT waterfront, COUNT(*) AS sales_count,
       AVG(price) AS avg_price_usd,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median_price_usd
FROM staging.clean_property_sales
GROUP BY waterfront;

-- @statement q1_highest_median_zipcodes
SELECT * FROM analytics.sales_by_zipcode
ORDER BY median_price_usd DESC, zipcode ASC
LIMIT 10;

-- @statement q2_monthly_activity
SELECT * FROM analytics.sales_by_month
ORDER BY sale_month;

-- @statement q3_most_recorded_sales
SELECT * FROM analytics.sales_by_zipcode
ORDER BY sales_count DESC, zipcode ASC
LIMIT 10;

-- @statement q4_price_by_grade
SELECT * FROM analytics.sales_by_grade
ORDER BY grade;

-- @statement q5_waterfront_comparison
SELECT * FROM analytics.sales_by_waterfront
ORDER BY waterfront;