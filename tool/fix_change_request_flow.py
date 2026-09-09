from pathlib import Path

# Extend Place with request metadata.
p = Path('lib/models/place.dart')
s = p.read_text()
s = s.replace("    this.approvalStatus = 'pending',\n  });", "    this.approvalStatus = 'pending',\n    this.requestType = 'new',\n    this.targetPlaceId = '',\n  });", 1)
s = s.replace("  String approvalStatus;\n", "  String approvalStatus;\n  String requestType;\n  String targetPlaceId;\n", 1)
s = s.replace("        'approvalStatus': approvalStatus,\n", "        'approvalStatus': approvalStatus,\n        'requestType': requestType,\n        'targetPlaceId': targetPlaceId,\n", 1)
s = s.replace("        'status': status,\n      };", "        'status': status,\n        'request_type': requestType,\n        'target_place_id': targetPlaceId.isEmpty ? null : targetPlaceId,\n      };", 1)
s = s.replace("        approvalStatus: '${j['approvalStatus'] ?? j['approval_status'] ?? 'pending'}',\n      );", "        approvalStatus: '${j['approvalStatus'] ?? j['approval_status'] ?? 'pending'}',\n        requestType: '${j['requestType'] ?? j['request_type'] ?? 'new'}',\n        targetPlaceId: '${j['targetPlaceId'] ?? j['target_place_id'] ?? ''}',\n      );", 1)
p.write_text(s)

# Approvals go through an atomic server RPC so change requests overwrite the original place.
p = Path('lib/repositories/supabase_repository.dart')
s = p.read_text()
old = """  @override\n  Future<void> approvePlace(String placeId) async {\n    await client.from('places').update({'approval_status': 'approved', 'approved_at': DateTime.now().toIso8601String(), 'approved_by': _uid}).eq('id', placeId);\n  }\n"""
new = """  @override\n  Future<void> approvePlace(String placeId) async {\n    await client.rpc('approve_place_request', params: {'p_request_id': placeId});\n  }\n"""
if old not in s:
    raise SystemExit('approvePlace pattern not found')
s = s.replace(old, new, 1)
p.write_text(s)

# Registration: exact approved address match becomes a change request after confirmation.
p = Path('lib/screens/home_screen.dart')
s = p.read_text()
old = """  Future<void> _openAddPlace(LatLng spot) async {\n    final name = TextEditingController();\n    final hours = TextEditingController();\n    final maxHeight = TextEditingController();\n    final phone = TextEditingController();\n    final note = TextEditingController();\n    final address = TextEditingController(text: await _reverseAddress(spot));\n    final prices = <String, TextEditingController>{\n      '블랙탱크 비움': TextEditingController(),\n      '급수': TextEditingController(),\n      '노지/차박': TextEditingController(),\n      '공중화장실': TextEditingController(),\n    };\n    final selected = <String>{};\n    final photos = <XFile>[];\n    String reservation = '예약불필요';\n"""
new = """  Future<void> _openAddPlace(LatLng spot) async {\n    final resolvedAddress = await _reverseAddress(spot);\n    String normalizeAddress(String value) => value.replaceAll(RegExp(r'\\s+'), '').trim().toLowerCase();\n    Place? existingPlace;\n    if (resolvedAddress.trim().isNotEmpty) {\n      for (final candidate in places) {\n        if (candidate.isApproved &&\n            candidate.requestType == 'new' &&\n            normalizeAddress(candidate.address) == normalizeAddress(resolvedAddress)) {\n          existingPlace = candidate;\n          break;\n        }\n      }\n    }\n    bool changeRequest = false;\n    if (existingPlace != null) {\n      if (!mounted) return;\n      final yes = await showDialog<bool>(\n        context: context,\n        builder: (ctx) => AlertDialog(\n          title: const Text('이미 등록된 주소지입니다.'),\n          content: const Text('변경 요청을 하시겠습니까?'),\n          actions: [\n            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니오')),\n            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('예')),\n          ],\n        ),\n      );\n      if (yes != true) return;\n      changeRequest = true;\n    }\n\n    final name = TextEditingController(text: changeRequest ? existingPlace!.name.replaceFirst(RegExp(r'^\\[(승인 대기|승인 반려)\\]\\s*'), '') : '');\n    final hours = TextEditingController(text: changeRequest ? existingPlace!.hours : '');\n    final maxHeight = TextEditingController(text: changeRequest && existingPlace!.maxHeightMm != null ? (existingPlace!.maxHeightMm! / 1000).toStringAsFixed(2) : '');\n    final phone = TextEditingController(text: changeRequest ? existingPlace!.phone : '');\n    final note = TextEditingController(text: changeRequest ? existingPlace!.note : '');\n    final address = TextEditingController(text: resolvedAddress);\n    final prices = <String, TextEditingController>{\n      '블랙탱크 비움': TextEditingController(text: changeRequest ? (existingPlace!.prices['블랙탱크 비움'] ?? '') : ''),\n      '급수': TextEditingController(text: changeRequest ? (existingPlace!.prices['급수'] ?? '') : ''),\n      '노지/차박': TextEditingController(text: changeRequest ? (existingPlace!.prices['노지/차박'] ?? '') : ''),\n      '공중화장실': TextEditingController(text: changeRequest ? (existingPlace!.prices['공중화장실'] ?? '') : ''),\n    };\n    final selected = changeRequest ? existingPlace!.services.toSet() : <String>{};\n    final photos = <XFile>[];\n    String reservation = changeRequest && existingPlace!.reservation.isNotEmpty ? existingPlace!.reservation : '예약불필요';\n"""
if old not in s:
    raise SystemExit('registration opening pattern not found')
s = s.replace(old, new, 1)
s = s.replace("              title: const Text('새 장소 등록'),", "              title: Text(changeRequest ? '장소 변경 요청' : '새 장소 등록'),", 1)
s = s.replace("                          approvalStatus: 'pending',\n                        );", "                          approvalStatus: 'pending',\n                          requestType: changeRequest ? 'change' : 'new',\n                          targetPlaceId: changeRequest ? existingPlace!.id : '',\n                        );", 1)
s = s.replace("                        _msg('장소가 접수되었습니다. 관리자 승인 진행중입니다.');", "                        _msg(changeRequest ? '장소 변경 요청이 접수되었습니다. 관리자 승인 진행중입니다.' : '장소가 접수되었습니다. 관리자 승인 진행중입니다.');", 1)
p.write_text(s)

# Admin approval list/detail clearly identify 신규 vs 변경.
p = Path('lib/screens/admin_home_screen.dart')
s = p.read_text()
old_title = """                          title: Text(p.name.replaceFirst(RegExp(r'^\\[(승인 대기|승인 반려)\\]\\s*'), '')),\n"""
new_title = """                          title: Text('${p.requestType == 'change' ? '[변경]' : '[신규]'} ${p.name.replaceFirst(RegExp(r'^\\[(승인 대기|승인 반려)\\]\\s*'), '')}'),\n"""
if old_title not in s:
    raise SystemExit('admin pending title pattern not found')
s = s.replace(old_title, new_title, 1)
s = s.replace("      appBar: AppBar(title: const Text('등록 장소 확인')),", "      appBar: AppBar(title: Text(p.requestType == 'change' ? '변경 요청 확인' : '신규 장소 확인')),", 1)
p.write_text(s)
