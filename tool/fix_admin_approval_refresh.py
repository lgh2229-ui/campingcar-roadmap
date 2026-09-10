from pathlib import Path

p = Path('lib/screens/admin_home_screen.dart')
s = p.read_text(encoding='utf-8')

s = s.replace(
"class _AdminHomeScreenState extends State<AdminHomeScreen> {\n  bool busy = false;",
"class _AdminHomeScreenState extends State<AdminHomeScreen> {\n  bool busy = false;\n  int homeRefreshKey = 0;"
)

s = s.replace(
"                            )).then((_) => setState(() {}));",
"                            )).then((changed) {\n                              if (changed == true && mounted) {\n                                setState(() => homeRefreshKey++);\n                              }\n                            });"
)

s = s.replace(
"      HomeScreen(\n        user: widget.user,",
"      HomeScreen(\n        key: ValueKey(homeRefreshKey),\n        user: widget.user,"
)

p.write_text(s, encoding='utf-8')
print('patched admin approval immediate map refresh')
