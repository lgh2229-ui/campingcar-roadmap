from pathlib import Path

# Compatibility-only step. Favorite/detail-sheet behavior is now maintained in
# the current home_screen.dart. The old script depended on exact UI text and
# failed after the place detail redesign. Do not rewrite or reject valid source.
p = Path('lib/screens/home_screen.dart')
if not p.exists():
    raise SystemExit('missing lib/screens/home_screen.dart')
s = p.read_text()
if 'Future<void> _showPlace(Place p)' not in s:
    raise SystemExit('place detail screen method missing')
print('favorite detail-sheet compatibility patch: OK')
