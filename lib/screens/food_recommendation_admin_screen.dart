import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodRecommendationAdminScreen extends StatefulWidget {
  const FoodRecommendationAdminScreen({super.key});

  @override
  State<FoodRecommendationAdminScreen> createState() =>
      _FoodRecommendationAdminScreenState();
}

class _FoodRecommendationAdminScreenState
    extends State<FoodRecommendationAdminScreen> {
  final db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> pending = _load();
  bool busy = false;
  bool showDone = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await db.from('food_recommendations')
        .select('id,name,category,address,comment,origin_place_id,user_id,status,latitude,longitude,created_at')
        .eq('status', showDone ? 'approved' : 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _update(Map<String, dynamic> item, String status) async {
    if (busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(status == 'approved' ? '맛집 추천 승인' : '맛집 추천 반려'),
        content: Text('${item['name']}\n${item['address']}\n\n이 추천을 ${status == 'approved' ? '승인' : '반려'}할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: Text(status == 'approved' ? '승인' : '반려')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => busy = true);
    try {
      final rows = await db.from('food_recommendations').update({
        'status': status,
        'approved_by': db.auth.currentUser!.id,
        'approved_at': status == 'approved'
            ? DateTime.now().toUtc().toIso8601String() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', item['id']).eq('status', 'pending').select('id');
      if (rows.isEmpty) throw StateError('이미 처리됐거나 승인 권한이 없습니다.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'approved'
            ? '승인했습니다. 주변맛집 목록에 공개됩니다.' : '추천을 반려했습니다.'),
      ));
      setState(() { pending = _load(); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리하지 못했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('맛집 추천 승인')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('승인 대기')),
              ButtonSegment(value: true, label: Text('승인 완료')),
            ],
            selected: {showDone},
            onSelectionChanged: (values) => setState(() {
              showDone = values.first;
              pending = _load();
            }),
          ),
        ),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: pending,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return const Center(
              child: Text('추천 목록을 불러오지 못했습니다.'),
            );
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) return Center(child: Text(showDone
                ? '승인된 맛집 추천이 없습니다.' : '대기 중인 맛집 추천이 없습니다.'));
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final x = rows[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${x['name']} · ${x['category']}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text('${x['address'] ?? ''}'),
                      if ('${x['comment'] ?? ''}'.trim().isNotEmpty)
                        Text('추천 이유: ${x['comment']}'),
                      Text('위치: ${x['latitude']}, ${x['longitude']}',
                        style: const TextStyle(fontSize: 11)),
                      if (!showDone) Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Expanded(child: OutlinedButton(
                            onPressed: busy ? null : () => _update(x, 'rejected'),
                            child: const Text('반려'),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: FilledButton.icon(
                            onPressed: busy ? null : () => _update(x, 'approved'),
                            icon: const Icon(Icons.check),
                            label: const Text('승인'),
                          )),
                        ]),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        )),
      ],
    ),
  );
}
