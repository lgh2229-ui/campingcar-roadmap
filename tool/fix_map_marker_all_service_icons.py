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

if old in s:
    s = s.replace(old, new, 1)
    p.write_text(s, encoding='utf-8')
    print('patched map markers to show all service icons')
else:
    print('legacy 3-icon marker fragment not present; continuing')

# IMPORTANT: Do not rewrite vehicle_market_screen.dart here.
# The market screen is maintained as source and must survive CI unchanged.
print('vehicle market source preserved; no legacy build-method overwrite')
