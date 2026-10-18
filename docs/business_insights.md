# Business Findings

These observations describe 21,613 recorded King County residential transactions from 2 May 2014 through 27 May 2015. They summarize this historical sample and do not establish causal effects or unobserved housing demand.

| Question | Finding | Interpretation and limitation | Saved evidence |
|---|---|---|---|
| Which ZIP codes have the highest median prices? | 98039: $1,895,000, 50 transactions; 98004: $1,150,000, 317 transactions. | Compare medians alongside sample size; property mix differs across locations. | [Median prices by ZIP](../reports/sql_validation/q1_highest_median_zipcodes.csv) |
| When was recorded sales activity highest? | April 2015: 2,231 transactions. | First and last months have partial coverage; this short period cannot establish reliable annual seasonality. | [Monthly activity](../reports/sql_validation/q2_monthly_activity.csv) |
| Which areas have the most recorded transactions? | 98103: 602 transactions; 98038: 590 transactions. | These are counts of observed sales, not a direct measure of latent demand. | [Sales counts by ZIP](../reports/sql_validation/q3_most_recorded_sales.csv) |
| How do prices vary by grade? | Median prices for grades 7, 8, and 9 are $375,000, $510,000, and $720,000. | Grade is associated with price; location and other attributes also vary. | [Price by grade](../reports/sql_validation/q4_price_by_grade.csv) |
| How do waterfront prices compare? | Waterfront: $1,400,000 median, 163 transactions; non-waterfront: $450,000 median, 21,450 transactions. | The groups differ greatly in size and characteristics; the gap is not an isolated waterfront effect. | [Waterfront comparison](../reports/sql_validation/q5_waterfront_comparison.csv) |

The SQL queries, tables, charts, and interpretations are presented in [notebook 2](../notebooks/2_postgresql_property.ipynb). PostgreSQL aggregates are checked against Python results before the validation report is exported. The Power BI dashboard presents the same historical sales alongside the model's held-out test errors.
