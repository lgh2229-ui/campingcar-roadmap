import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';

class FoodRecommendationForm extends StatefulWidget {
  const FoodRecommendationForm({super.key, required this.place});
  final Place place;

  @override
  State<FoodRecommendationForm> createState() => _FoodRecommendationFormState();
}

class _FoodRecommendationFormState extends State<FoodRecommendationForm> {
  final name = TextEditingController();
  final reason = TextEditingController();
  List<Map<String, dynamic>> candidates = [];
  Map<String, dynamic>? chosen;
  bool searching = false;
  bool saving = false;
  String error = '';

  @override
  void dispose() {
    name.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> findRestaurant() async {
    final text = name.text.trim();
    if (text.length < 2) {
      setState(() => error = '매장명을 2글자 이상 입력해주세요.');
      return;
    }
    setState(() { searching = true; error = ''; chosen = null; candidates = []; });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'nearby-food',
        body: {'mode': 'lookup', 'place_id': widget.place.id, 'query': text},
      );
      final data = response.data;
      if (data is! Map || data['error'] != null) {
        throw StateError('매장 검색을 완료하지 못했습니다.');
      }
      if (!mounted) return;
      setState(() {
        candidates = (data['spots'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList();
        error = candidates.isEmpty ? '반경 1km 안에서 일치하는 매장을 찾지 못했습니다.' : '';
      });
    } catch (_) {
      if (mounted) setState(() => error = '매장을 검색하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> submit() async {
    final shop = chosen;
    if (shop == null) {
      setState(() => error = '실제 매장 위치를 검색 결과에서 선택해주세요.');
      return;
    }
    if (saving) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => error = '로그인 후 추천할 수 있습니다.');
      return;
    }
    setState(() { saving = true; error = ''; });
    try {
      await Supabase.instance.client.from('food_recommendations').insert({
        'origin_place_id': widget.place.id,
        'user_id': user.id,
        'name': shop['name'],
        'category': shop['category'],
        'address': shop['address'],
        'latitude': shop['latitude'],
        'longitude': shop['longitude'],
        'comment': reason.text.trim(),
        'status': 'pending',
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() =>
          error = '추천 접수에 실패했습니다. 계정 또는 매장 정보를 확인해주세요.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 18, right: 18, top: 6,
      bottom: MediaQuery.of(context).viewInsets.bottom + 18,
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내 맛집 추천하기', style: TextStyle(
              fontSize: 21, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 6),
            Text('${widget.place.name} 반경 1km 내 매장만 추천할 수 있습니다.',
              style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              maxLength: 80,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => findRestaurant(),
              decoration: const InputDecoration(
                labelText: '식당·카페 이름',
                hintText: '매장명을 입력해주세요',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(width: double.infinity, child: FilledButton.tonalIcon(
              onPressed: searching ? null : findRestaurant,
              icon: const Icon(Icons.search),
              label: Text(searching ? '매장 확인 중' : '매장 위치 확인'),
            )),
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('추천할 매장을 선택하세요',
                style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(
                height: 210,
                child: ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, i) {
                    final item = candidates[i];
                    final selected = identical(chosen, item);
                    return ListTile(
                      dense: true,
                      selected: selected,
                      leading: Icon(selected
                          ? Icons.check_circle : Icons.restaurant_outlined),
                      title: Text('${item['name']}'),
                      subtitle: Text(
                        '${item['address'] ?? ''} · ${item['distance_m'] ?? '-'}m'),
                      onTap: () => setState(() { chosen = item; error = ''; }),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: reason,
              maxLength: 800,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '추천 이유 (선택)',
                hintText: '대표 메뉴와 추천 이유를 알려주세요.',
                border: OutlineInputBorder(),
              ),
            ),
            const Text('관리자가 승인한 뒤 주변맛집 목록에 공개됩니다.',
              style: TextStyle(fontSize: 12)),
            if (error.isNotEmpty) Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(error, style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              )),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: saving || chosen == null ? null : submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(saving ? '접수 중' : '관리자 승인 요청'),
            )),
          ],
        ),
      ),
    ),
  );
}
