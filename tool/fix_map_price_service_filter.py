from pathlib import Path

p = Path('lib/screens/home_screen.dart')
if not p.exists():
    raise SystemExit('missing lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

# Current checked-in HomeScreen still uses the simple `filter` state. Keep that
# implementation intact and only make this workflow step compatibility-safe.
# A previous version partially rewrote the UI to call _mapFilterButton without
# reliably installing its helper methods, which broke flutter analyze.
print('map filter compatibility patch: current HomeScreen retained')

# Admin controls: move only the exact legacy top offset if it still exists.
p = Path('lib/screens/admin_home_screen.dart')
if not p.exists():
    raise SystemExit('missing lib/screens/admin_home_screen.dart')
s = p.read_text(encoding='utf-8')
old = 'Positioned(top:MediaQuery.of(context).padding.top+12,right:12'
new = 'Positioned(top:MediaQuery.of(context).padding.top+118,right:12'
if old in s:
    p.write_text(s.replace(old, new, 1), encoding='utf-8')
    print('moved admin control group below map filters')
else:
    print('admin control position already redesigned/moved')
