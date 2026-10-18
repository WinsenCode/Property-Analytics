from pathlib import Path
import re

def get_engine(project_root):
    from dotenv import dotenv_values
    from sqlalchemy import URL, create_engine
    env_path = Path(project_root) / '.env'
    cfg = dotenv_values(env_path)
    required = ['PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD']
    absent = [key for key in required if not cfg.get(key)]
    if absent:
        raise ValueError('Missing .env settings: ' + ', '.join(absent))
    if cfg['PGDATABASE'] != 'property_analytics_database':
        raise ValueError('PGDATABASE should be property_analytics_database')
    url = URL.create('postgresql+psycopg', 
                     username = cfg['PGUSER'],
                     password = cfg['PGPASSWORD'],
                     host = cfg['PGHOST'],
                     port = int(cfg['PGPORT']),
                     database = cfg['PGDATABASE']
                     )
    return create_engine(url, pool_pre_ping = True, connect_args = {'connect_timeout': 5})

def load_sql_blocks(path):
    "Read named, single-statement blocks without splitting on SQL semicolons."
    
    content = Path(path).read_text(encoding = 'utf-8')
    matches = list(re.finditer(r'^-- @statement ([a-z0-9_]+)\s*$', content, re.MULTILINE))
    
    if not matches:
        raise ValueError(f'No named SQL blocks in {Path(path).name}')
    result = {}
    
    for i, match in enumerate(matches):
        name = match.group(1)
        if name in result:
            raise ValueError(f'Duplicate SQL block: {name}')
        end = matches[i + 1].start() if i + 1 < len(matches) else len(content)
        result[name] = content[match.end():end].strip()
    return result
    
def apply_sql_blocks(engine, blocks, names = None):
      "Commit the selected DDL statements together or roll back on an error."
      selected = list(blocks) if names is None else list(names)
      with engine.begin() as connection:
          for name in selected:
              connection.exec_driver_sql(blocks[name])
      return selected

def query_df(engine, query):
    import pandas as pd
    from sqlalchemy import text
    with engine.connect() as connection:
        return pd.read_sql_query(text(query), connection)
    
    