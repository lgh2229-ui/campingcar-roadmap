from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

# The previous workflow step turns the address Text into an InkWell for
# TMAP/KakaoMap. Anchor only on the service line so this patch works both
# before and after that transformation.
anchor = "        Text(p.services.join(' · ')),\n"
service_ui = """        const SizedBox(height: 8),
        const Text('이용가능 서비스', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...[
          ('블랙탱크', '블랙탱크 비움'),
          ('급수', '급수'),
          ('노지/차박', '노지/차박'),
          ('화장실', '공중화장실'),
        ].map((item) {
          final available = p.services.contains(item.$2);
          final price = available ? (p.prices[item.$2]?.trim() ?? '') : '';
          final value = available ? (price.isEmpty ? '금액정보 없음' : price) : '이용불가';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 105, child: Text('${item.$1} :', style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: Text(value)),
            ]),
          );
        }),
"""

if "const Text('이용가능 서비스'" in s:
    print('service availability/price display already present')
elif anchor in s:
    p.write_text(s.replace(anchor, service_ui, 1), encoding='utf-8')
    print('patched service availability/price display')
else:
    raise SystemExit('service line anchor not found')
