from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')

old = """        Text(p.services.join(' · ')),
        if (p.address.isNotEmpty) Text(p.address),
"""
new = """        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        if (p.address.isNotEmpty) Text(p.address),
"""

# Idempotent: if a previous run already added the service UI, succeed.
if "const Text('이용가능 서비스'" in s:
    print('service availability/price display already present')
elif old in s:
    p.write_text(s.replace(old, new, 1), encoding='utf-8')
    print('patched service availability/price display')
else:
    raise SystemExit('current place detail anchor not found')
