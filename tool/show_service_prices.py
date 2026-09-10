from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text(encoding='utf-8')
needle = "        Text(p.services.join(' · ')),\n        if (p.address.isNotEmpty) Text(p.address),"
replacement = """        const SizedBox(height: 8),
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
        if (p.address.isNotEmpty) Text(p.address),"""
if needle not in s:
    raise SystemExit('place service display anchor not found')
s = s.replace(needle, replacement, 1)
p.write_text(s, encoding='utf-8')
print('patched service price display')
