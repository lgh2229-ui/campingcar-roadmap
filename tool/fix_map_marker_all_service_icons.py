from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

old = """                          : Center(child: Text(_icons(p).take(3).join(), style: const TextStyle(fontSize: 18))),"""
new = """                          : Center(
                              child: Builder(builder: (_) {
                                final icons = _icons(p);
                                if (icons.length <= 2) {
                                  return Text(icons.join(), style: const TextStyle(fontSize: 18, height: 1));
                                }
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(icons.take(2).join(), style: const TextStyle(fontSize: 17, height: 1)),
                                    Text(icons.skip(2).join(), style: const TextStyle(fontSize: 14, height: 1)),
                                  ],
                                );
                              }),
                            ),"""

# The preceding filter patch can change this exact source fragment. Only patch it
# when the old 3-icon-limited marker is still present; otherwise continue to the
# requested redesign instead of failing the whole Android build.
if old in s:
    s = s.replace(old, new, 1)
    p.write_text(s, encoding='utf-8')
    print('patched map markers to show all service icons')
else:
    print('legacy 3-icon marker fragment not present; continuing with redesign')

# Apply the requested popup-filter / expanded-service / used-market redesign.
redesign = Path('tool/apply_requested_redesign.py')
if not redesign.exists():
    raise SystemExit('requested redesign script missing')
exec(redesign.read_text(encoding='utf-8'))
