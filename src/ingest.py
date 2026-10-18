from pathlib import Path
import csv
import hashlib
import io

RAW_COLUMNS = [
    'id', 
    'date', 
    'price', 
    'bedrooms', 
    'bathrooms', 
    'sqft_living', 
    'sqft_lot',
    'floors', 
    'waterfront', 
    'view', 
    'condition', 
    'grade', 
    'sqft_above',
    'sqft_basement', 
    'yr_built', 
    'yr_renovated', 
    'zipcode', 
    'lat', 
    'long',
    'sqft_living15', 
    'sqft_lot15'
]

def read_source_rows(path):
    "Read once so the digest and imported records describe the same bytes."
    raw_bytes = Path(path).read_bytes()
    digest = hashlib.sha256(raw_bytes).hexdigest()
    rows = []
    with io.StringIO(raw_bytes.decode('utf-8-sig'), newline = '') as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != RAW_COLUMNS:
            raise ValueError('CSV columns/order differ from the audited data contract.')
        for source_row, row in enumerate(reader, start = 1):
            if set(row) != set(RAW_COLUMNS) or any(value is None for value in row.values()):
                raise ValueError(f'Malformed CSV record at source row {source_row}.')
            rows.append({'source_sha256': digest, 'source_row': source_row, **row})
        if not rows:
            raise ValueError('CSV contains no data rows.')
        return digest, rows

def import_raw_csv(engine, path, expected_sha256):
    "Single-file learning dataset. A rerun never appends the same file twice."
    from sqlalchemy import text
    path = Path(path)
    digest, rows = read_source_rows(path)
    if digest != expected_sha256:
        raise ValueError('Raw file hash does not match the exported audit reference. Recheck the source.')
    names = ['source_sha256', 'source_row'] + RAW_COLUMNS
    quoted = ', '.join('"' + name + '"' for name in names)
    placeholders = ', '.join(':' + name for name in names)
    insert = text(f'INSERT INTO raw.raw_property_sales ({quoted}) VALUES ({placeholders})')
    with engine.begin() as connection:
        connection.exec_driver_sql('LOCK TABLE raw.raw_property_sales IN SHARE ROW EXCLUSIVE MODE')
        manifests = connection.execute(text('SELECT source_sha256, row_count FROM raw.ingestion_log')).mappings().all()
        total = connection.execute(text('SELECT COUNT(*) FROM raw.raw_property_sales')).scalar_one()
        
        if manifests:
            if len(manifests) != 1 or manifests[0]['source_sha256'] != digest:
                raise ValueError('Already contains a different source. No data were overwritten.')
            count = connection.execute(text('SELECT COUNT(*) FROM raw.raw_property_sales WHERE source_sha256 = :sha'), {'sha': digest}).scalar_one()
            if total != len(rows) or count != len(rows) or manifests[0]['row_count'] != len(rows):
                raise ValueError('Existing import row counts are inconsistent. Inspect before proceeding.')
            return {'status': 'already_loaded', 'rows': int(count), 'source_sha256': digest}

        if total != 0:
            raise ValueError('Raw rows exist without an import manifest. No data were overwritten.')
        connection.execute(text('INSERT INTO raw.ingestion_log (source_sha256, source_file_name, row_count) '
                                'VALUES (:sha, :name, :count)'
                                ), {'sha': digest, 'name': path.name, 'count': len(rows)})
        for start in range(0, len(rows), 1000):
            connection.execute(insert, rows[start:start + 1000])
        actual = connection.execute(text('SELECT COUNT(*) FROM raw.raw_property_sales')).scalar_one()
        if actual != len(rows):
            raise ValueError('Imported row count differs from source; transaction will be rolled back')
    return {'status': 'imported', 'rows': int(actual), 'source_sha256': digest}
        