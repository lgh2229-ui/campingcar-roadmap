from pathlib import Path

p = Path('lib/screens/home_screen.dart')
s = p.read_text()
start = s.index('  Future<void> _openAddPlace(LatLng spot) async {')
end = s.index('  Widget _placePhoto(String value) {', start)
method = r'''  Future<void> _openAddPlace(LatLng spot) async {
    final name = TextEditingController();
    final hours = TextEditingController();
    final maxHeight = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final address = TextEditingController(text: await _reverseAddress(spot));
    final prices = <String, TextEditingController>{
      '블랙탱크 비움': TextEditingController(),
      '급수': TextEditingController(),
      '노지/차박': TextEditingController(),
      '공중화장실': TextEditingController(),
    };
    final selected = <String>{};
    final photos = <XFile>[];
    String reservation = '예약불필요';
    bool saving = false;
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => StatefulBuilder(
          builder: (pageContext, setPageState) => Scaffold(
            appBar: AppBar(
              title: const Text('새 장소 등록'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: saving ? null : () => Navigator.pop(pageContext),
              ),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(pageContext).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('등록 위치 ${spot.latitude.toStringAsFixed(6)}, ${spot.longitude.toStringAsFixed(6)}'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: '장소명', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: address, decoration: const InputDecoration(labelText: '주소 (한국 도로명주소)', border: OutlineInputBorder())),
                  const SizedBox(height: 18),
                  const Text('서비스 항목 및 금액', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  ...prices.entries.map((e) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                      child: Row(children: [
                        Checkbox(
                          value: selected.contains(e.key),
                          onChanged: saving ? null : (v) => setPageState(() {
                            if (v == true) {
                              selected.add(e.key);
                            } else {
                              selected.remove(e.key);
                              e.value.clear();
                            }
                          }),
                        ),
                        Expanded(flex: 2, child: Text(e.key)),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: e.value,
                            enabled: selected.contains(e.key) && !saving,
                            decoration: const InputDecoration(hintText: '금액 / 무료', isDense: true),
                          ),
                        ),
                      ]),
                    ),
                  )),
                  const SizedBox(height: 12),
                  TextField(controller: hours, enabled: !saving, decoration: const InputDecoration(labelText: '운영시간', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: reservation,
                    items: ['예약불필요', '예약필수', '전화문의'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: saving ? null : (v) => reservation = v ?? reservation,
                    decoration: const InputDecoration(labelText: '예약 여부', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxHeight,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '진입 최대 높이', hintText: '예: 3.2', suffixText: 'm', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: phone, enabled: !saving, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '문의연락처', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: note, enabled: !saving, maxLines: 3, decoration: const InputDecoration(labelText: '이용방법 / 주의사항', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () async {
                      final picked = await ImagePicker().pickMultiImage(imageQuality: 82, limit: 6);
                      if (!pageContext.mounted) return;
                      setPageState(() {
                        photos
                          ..clear()
                          ..addAll(picked);
                      });
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text('장소사진 ${photos.isEmpty ? '' : '(${photos.length})'}'),
                  ),
                  const SizedBox(height: 4),
                  const Text('장소사진은 최소 1장 필요합니다.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 14),
                  const Text('등록 후 관리자 승인 전까지 일반 사용자 지도에는 공개되지 않습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: saving ? null : () async {
                      void msg(String text) => ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text(text)));
                      if (name.text.trim().isEmpty || selected.isEmpty) {
                        msg('장소명과 서비스 항목을 입력해주세요.');
                        return;
                      }
                      for (final service in selected) {
                        if (prices[service]!.text.trim().isEmpty) {
                          msg('$service 금액을 입력해주세요. 무료면 "무료"라고 입력해주세요.');
                          return;
                        }
                      }
                      if (photos.isEmpty) {
                        msg('장소사진을 1장 이상 등록해주세요.');
                        return;
                      }
                      setPageState(() => saving = true);
                      try {
                        final place = Place(
                          id: const Uuid().v4(),
                          name: name.text.trim(),
                          latitude: spot.latitude,
                          longitude: spot.longitude,
                          address: address.text.trim(),
                          services: selected.toList(),
                          prices: {for (final service in selected) service: prices[service]!.text.trim()},
                          hours: hours.text.trim(),
                          reservation: reservation,
                          maxHeightMm: maxHeight.text.trim().isEmpty ? null : _metersToMm(maxHeight.text),
                          phone: phone.text.trim(),
                          note: note.text.trim(),
                          ownerId: _currentAuthorId,
                          approvalStatus: 'pending',
                        );
                        await widget.data.addPlace(place);
                        place.photoUrls = await widget.data.uploadPlacePhotos(
                          place.id,
                          photos.map((e) => File(e.path)).toList(),
                        );
                        selectedSpot = null;
                        if (pageContext.mounted) Navigator.pop(pageContext);
                        await _load();
                        if (mounted) setState(() => tab = 2);
                        _msg('장소가 접수되었습니다. 관리자 승인 진행중입니다.');
                      } catch (e) {
                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text('장소 등록에 실패했습니다: $e')));
                          setPageState(() => saving = false);
                        }
                      }
                    },
                    icon: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_location_alt_outlined),
                    label: Text(saving ? '등록 중...' : '등록 요청'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

'''
p.write_text(s[:start] + method + s[end:])
