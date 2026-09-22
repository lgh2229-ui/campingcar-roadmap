from pathlib import Path

# Compatibility-only build step. Service availability/prices are maintained in
# the current place detail UI. The old patch matched an obsolete address block
# and aborted after the address became a TMAP/KakaoMap link.
p = Path('lib/screens/home_screen.dart')
if not p.exists():
    raise SystemExit('missing lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')
if 'p.services' not in s or 'p.prices' not in s:
    raise SystemExit('service/price support missing from place detail source')
print('service availability/price compatibility patch: OK')
