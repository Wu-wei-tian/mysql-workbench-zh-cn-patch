"""Exercise CLI dump/reload on the disposable loopback fixture, never personal data."""
# SPDX-License-Identifier: GPL-2.0-only
import json
import os
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
binary = Path(os.environ.get('MYSQL_TEST_BIN', r'C:\Program Files\MySQL\MySQL Server 8.4\bin'))
args = ['--no-defaults', '--protocol=TCP', '--host=127.0.0.1', '--port=13367', '--user=root']

def query(sql):
    return subprocess.run([str(binary / 'mysql.exe'), *args, '--default-character-set=utf8mb4', '--batch', '--skip-column-names', '--execute', sql], check=True, capture_output=True, encoding='utf-8').stdout.strip()

data_dir = Path(query('SELECT @@datadir')).resolve()
if data_dir != (root / 'build/test-db').resolve():
    raise RuntimeError('Refusing to modify a non-fixture MySQL server')

if not query("SHOW COLUMNS FROM localization_qa.`Language` LIKE 'IF_NOT_USED'"):
    query('ALTER TABLE localization_qa.`Language` ADD COLUMN IF_NOT_USED INT NULL')
if 'idx_label' not in query('SHOW INDEXES FROM localization_qa.`Language`'):
    query('CREATE INDEX idx_label ON localization_qa.`Language` (label)')
query('CREATE OR REPLACE VIEW localization_qa.qa_view AS SELECT id,label FROM localization_qa.`Language`')
assert 'idx_label' in query('SHOW INDEXES FROM localization_qa.`Language`')
assert query('SELECT label FROM localization_qa.qa_view WHERE id=1') == 'Save'
dump = root / 'build/roundtrip.sql'
subprocess.run([str(binary / 'mysqldump.exe'), *args, '--default-character-set=utf8mb4', '--no-tablespaces', '--skip-comments', '--skip-dump-date', '--result-file=' + str(dump), 'localization_qa', 'Language'], check=True, capture_output=True)
query('CREATE DATABASE IF NOT EXISTS localization_qa_import CHARACTER SET utf8mb4')
with dump.open('rb') as stream:
    subprocess.run([str(binary / 'mysql.exe'), *args, '--default-character-set=utf8mb4', 'localization_qa_import'], stdin=stream, check=True, capture_output=True)
rows = query('SELECT id,label FROM localization_qa_import.`Language` ORDER BY id')
assert rows == '1\tSave\n2\t简体中文测试', repr(rows)
result = {'status': 'PASS', 'table_alter_index_view': True, 'cli_dump_reload_unicode': True,
          'ui_import_export': 'Not tested: upstream result import/export menu is disabled', 'rows': 2}
(root / 'logs/data-roundtrip.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
