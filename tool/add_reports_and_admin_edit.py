from pathlib import Path

# Compatibility-only step. Reports/admin editing are maintained in the current
# Dart source. The former patch depended on exact UI strings and became brittle
# after the admin redesign, so it must not rewrite or reject the current UI.
required = [
    Path('lib/repositories/app_data_repository.dart'),
    Path('lib/repositories/supabase_repository.dart'),
    Path('lib/repositories/local_repository.dart'),
    Path('lib/screens/home_screen.dart'),
    Path('lib/screens/admin_home_screen.dart'),
]
missing = [str(p) for p in required if not p.exists()]
if missing:
    raise SystemExit('missing required source files: ' + ', '.join(missing))
print('reports/admin-edit compatibility patch: OK')
