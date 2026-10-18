"""Check saved-run provenance without retraining or querying PostgreSQL."""
from pathlib import Path
import hashlib
import json
import sys


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    root = Path(__file__).resolve().parents[1]
    report = json.loads((root / 'reports/modeling/modeling_report.json').read_text(encoding='utf-8'))
    issues = []
    if report.get('status') != 'completed_and_reloaded':
        issues.append('Modeling report does not say completed_and_reloaded.')
    for relative, expected in report['output_sha256'].items():
        path = root / relative
        if not path.is_file() or sha(path) != expected:
            issues.append('Missing or changed output: ' + relative)
    inputs = {
        'raw_csv': 'data/raw/kc_house_data.csv',
        'clean_reference': 'data/reference/audit_clean_reference.csv',
        'audit_manifest': 'data/reference/audit_reference_manifest.json',
        'step2_report': 'reports/sql_validation/validation_report.json'
    }
    for key, relative in inputs.items():
        if sha(root / relative) != report['input_sha256'][key]:
            issues.append('Changed input: ' + relative)
    for name, expected in report['sql_sha256'].items():
        if sha(root / 'sql' / name) != expected:
            issues.append('Changed SQL: ' + name)
    notebook = json.loads((root / 'notebooks/3_modeling.ipynb').read_text(encoding='utf-8'))
    sources = [''.join(c['source']) for c in notebook['cells'] if c['cell_type'] == 'code']
    current = hashlib.sha256(json.dumps(sources, ensure_ascii=False).encode('utf-8')).hexdigest()
    if current != report['saved_notebook_code_sha256']:
        issues.append('Saved notebook code differs from the export record. Save the notebook, '
                      'Restart Kernel, Run All with the same model/split, then save outputs.')
    if issues:
        print('CHECK_FAILED')
        for issue in issues:
            print('- ' + issue)
        return 1
    print('CHECK_PASSED: notebook code, source, SQL and all saved modeling outputs match.')
    return 0

if __name__ == '__main__':
    sys.exit(main())