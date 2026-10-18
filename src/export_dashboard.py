"""Export reviewed local results for Power BI. Run from root: python -m src.export_dashboard."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import pandas as pd

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    root = Path(__file__).resolve().parents[1]
    destination = root / 'dashboard/data'
    report_path = root / 'reports/modeling/modeling_report.json'
    report = json.loads(report_path.read_text(encoding='utf-8'))
    if report['status'] != 'completed_and_reloaded':
        raise ValueError('Modeling export is not complete.')
    reference_path = root / 'data/reference/audit_clean_reference.csv'
    if digest(reference_path) != report['input_sha256']['clean_reference']:
        raise ValueError('Audit reference differs from the modeling run.')
    for filename in ['split_assignments.csv', 'test_predictions.csv']:
        relative = 'reports/modeling/' + filename
        if digest(root / relative) != report['output_sha256'][relative]:
            raise ValueError(f'Output differs from modeling report: {filename}')
    sales = pd.read_csv(reference_path, dtype={'id': str, 'zipcode': str})
    split = pd.read_csv(root / 'reports/modeling/split_assignments.csv')
    test = pd.read_csv(root / 'reports/modeling/test_predictions.csv')
    if not all(frame['source_row'].is_unique for frame in [sales, split, test]):
        raise ValueError('Duplicate source_row would multiply the dashboard join.')
    if set(sales['source_row']) != set(split['source_row']):
        raise ValueError('Split keys do not cover the audited source.')
    test_rows = set(split.loc[split['split'].eq('test'), 'source_row'])
    if set(test['source_row']) != test_rows:
        raise ValueError('Test predictions do not match the test split.')
    test = test.rename(columns={
        'predicted_price_usd': 'test_predicted_price_usd',
        'absolute_error_usd': 'test_absolute_error_usd',
        'residual_usd': 'test_residual_usd',
        'baseline_prediction_usd': 'test_baseline_prediction_usd',
        'price_segment': 'test_price_segment',
        'property_history': 'test_property_history'
    })
    keep = ['source_row', 'actual_price_usd', 'test_predicted_price_usd',
            'test_absolute_error_usd', 'test_residual_usd', 'test_baseline_prediction_usd',
            'test_price_segment', 'test_property_history']
    output = sales.merge(split[['source_row', 'split']], on='source_row', validate='one_to_one')
    output = output.merge(test[keep], on='source_row', how='left', validate='one_to_one')
    test_mask = output['split'].eq('test')
    if len(output) != len(sales) or output.loc[~test_mask, 'test_predicted_price_usd'].notna().any():
        raise ValueError('Dashboard row count or prediction scope is invalid.')
    if not output.loc[test_mask, 'price'].eq(output.loc[test_mask, 'actual_price_usd']).all():
        raise ValueError('Test targets do not match the audit reference.')
    output = output.drop(columns=['actual_price_usd'])
    dates = pd.to_datetime(output['date'], errors='raise')
    output['sale_month'] = dates.dt.to_period('M').dt.to_timestamp().dt.strftime('%Y-%m-%d')
    output['is_boundary_month'] = dates.dt.to_period('M').isin(
        [dates.min().to_period('M'), dates.max().to_period('M')]
    )
    output['waterfront_label'] = output['waterfront'].map({0: 'Non-waterfront', 1: 'Waterfront'})
    output['test_squared_error_usd2'] = output['test_residual_usd'].pow(2)
    output['test_baseline_absolute_error_usd'] = (
        output['price'] - output['test_baseline_prediction_usd']
    ).abs()
    path = destination / 'property_sales_dashboard.csv'
    output.to_csv(path, index=False)
    manifest = {
        'source': 'Audited clean reference joined to verified split and saved test predictions; no live database query.',
        'modeling_report_sha256': digest(report_path),
        'rows': len(output), 'unique_properties': int(output['id'].nunique()),
        'test_prediction_rows': int(test_mask.sum()),
        'median_price_usd': float(output['price'].median()),
        'test_mae_usd': float(output['test_absolute_error_usd'].mean()),
        'csv_sha256': digest(path),
        'refresh': 'After rerunning modeling, rerun this command, then refresh Power BI.',
        'limitation': 'Static historical snapshot. Test prediction fields remain blank outside test.'
    }
    (destination / 'export_manifest.json').write_text(
        json.dumps(manifest, indent=2), encoding='utf-8'
    )
    print(f'Saved {len(output):,} rows to {path.relative_to(root)}; '
          f'{int(test_mask.sum()):,} test predictions.')

if __name__ == '__main__':
    main()