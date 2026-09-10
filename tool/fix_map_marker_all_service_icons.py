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
                                    Text(icons.skip(2).join(), style: const TextStyle(fontSize: 17, height: 1)),
                                  ],
                                );
                              }),
                            ),"""

if old not in s:
    raise SystemExit('map marker 3-icon limit pattern not found')

s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('patched map markers to show all service icons in a 2x2-friendly layout')
