# Model Card: Historical House Price Regression

## Purpose and scope

Estimate transaction prices for later sales within the historical King County dataset. This is a reproducible portfolio benchmark using recorded property attributes. Its evaluation does not establish suitability for current property appraisal or operational lending decisions.

## Data and preparation

The source contains 21,613 transactions for 21,436 distinct properties from May 2014 through May 2015. Python and SQL cleaning are compared across all 28 cleaned columns. Repeated property IDs are retained as separate transactions; no exact transaction duplicates were found.

The raw values remain available for audit. One implausible bedroom value, 12 future construction years, and six future renovation years are masked as unknown. Prices are retained without capping or deleting high-value transactions. Median imputation and missing-value indicators are fitted within the modeling pipeline.

The target is price in USD. There are 17 predictors: 16 numeric property/location features and categorical ZIP code. IDs, target values, raw backup fields, direct dates, and the two neighborhood `*15` columns are excluded. See the [feature schema](../reports/modeling/feature_schema.json) for exact names, order, units, and missing-value rules.

## Experiment design

| Split | Period | Rows |
|---|---|---:|
| Training | Before 2015-01-01 | 14,633 |
| Validation | January–February 2015 | 2,228 |
| Test | March–May 2015 | 4,752 |

Selection minimizes validation MAE across a median baseline, Ridge regression, and Random Forest. Random Forest uses 200 trees, maximum depth 20, minimum leaf size 3, all features per split, random seed 42, and two workers. No hyperparameter search was performed.

The selected pipeline is refitted on the 16,861 training and validation rows through 28 February 2015. The median baseline is refitted on the same rows. Test data are excluded from fitting and candidate selection.

## Test performance

| Model | MAE (USD) | RMSE (USD) | R² | Median absolute error (USD) |
|---|---:|---:|---:|---:|
| Random Forest | 76,958.43 | 139,854.34 | 0.8578 | 44,465.90 |
| Median baseline | 226,622.19 | 385,509.10 | -0.0807 | 149,075.00 |

Random Forest reduces MAE by 66.04% relative to the baseline. This is an error reduction, not a prediction accuracy percentage. Full interpretation is included directly in [notebook 3, Section 14](../notebooks/3_modeling.ipynb).

## Known limitations

- Test MAE is $245,791 for actual prices above the training P90 of $883,000 (527 transactions), and $478,328 for waterfront properties (35 transactions). Both groups are underpredicted on average.
- Full-file exploration preceded modeling, and property IDs overlap across periods. This is a later-transaction evaluation, not a strictly unseen-property benchmark.
- Historical availability of all predictors at listing time is not established. Age features require a known valuation year and the audited year-handling policy.
- ZIP-level metrics with small samples are uncertain. Feature importance and segment comparisons do not establish causation.
- The experiment provides no prediction intervals, evidence of geographic transfer, or current-market validation. Future model selection should use a new documented validation/evaluation plan instead of optimizing against this observed test result.

## Saved artifact and reproducibility

The fitted pipeline is [property_price_pipeline.joblib](../models/property_price_pipeline.joblib). [Model metadata](../models/model_metadata.json) records the feature schema, fit period, parameters, package versions, model hash, and successful reload check.  

Use the recorded Python/package environment, including scikit-learn 1.7.2, to reload the model. Prediction inputs must contain the 17 feature columns with the same units, derived-age definitions, categorical representation, and missing-value policy. Notebook 3 includes a feature-only reload example.

Run `python -m src.check_modeling_artifacts` from the repository root to compare saved notebook code, four recorded input files, five SQL scripts, and 22 output files with the modeling report. This verifies the supplied artifact set without training a new model.
