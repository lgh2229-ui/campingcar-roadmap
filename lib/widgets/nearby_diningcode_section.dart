import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';
import 'food_recommendation_form.dart';
import '../utils/nearby_food_naver_link.dart';
import '../utils/food_open_status.dart';
import '../utils/nearby_food_ranking.dart';

/// Every tap fetches one-kilometre food results automatically. The server
/// caches nearby external places and includes admin-approved member picks.
class NearbyDiningCodeSection extends StatefulWidget {
  const NearbyDiningCodeSection({super.key, required this.place});
  final Place place;

  @override
  State<NearbyDiningCodeSection> createState() => _NearbyDiningCodeSectionState();
}

class _DiningSpot {
  const _DiningSpot({
    required this.rank,
    required this.name,
    required this.category,
    required this.address,
    required this.score,
    required this.distanceM,
    required this.url,
    required this.source,
    required this.comment,
    required this.openingHours,
  });
  final int? rank;
  final String name;
  final String category;
  final String address;
  final int? score;
  final int distanceM;
  final String url;
  final String source;
  final String comment;
  final String? openingHours;

  factory _DiningSpot.fromJson(Map<String, dynamic> row) => _DiningSpot(
    rank: verifiedNearbyFoodRank(
      (row['score'] as num?)?.toInt(), (row['rank'] as num?)?.toInt()),
    name: (row['name'] ?? '').toString(),
    category: (row['category'] ?? '').toString(),
    address: (row['address'] ?? '').toString(),
    score: (row['score'] as num?)?.toInt(),
    distanceM: (row['distance_m'] as num?)?.toInt() ?? 0,
    url: (row['url'] ?? '').toString(),
    source: (row['source'] ?? '').toString(),
    comment: (row['comment'] ?? '').toString(),
    openingHours: (row['opening_hours'] as String?)?.trim(),
  );
}

class _NearbyDiningCodeSectionState extends State<NearbyDiningCodeSection> {
  late Future<List<_DiningSpot>> result = _fetch();
  Timer? _statusRefreshTimer;

  @override
  void initState() {
    super.initState();
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NearbyDiningCodeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id ||
        oldWidget.place.latitude != widget.place.latitude ||
        oldWidget.place.longitude != widget.place.longitude) {
      result = _fetch();
    }
  }

  Future<List<_DiningSpot>> _fetch() async {
    final response = await Supabase.instance.client.functions.invoke(
      'nearby-food',
      body: {'mode': 'list', 'place_id': widget.place.id},
    );
    final data = response.data;
    if (data is! Map || data['error'] != null || data['spots'] is! List) {
      throw StateError('주변맛집 조회 실패');
    }
    return (data['spots'] as List)
        .whereType<Map>()
        .map((row) => _DiningSpot.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> _openSpot(_DiningSpot spot) async {
    // Do not open Kakao/OSM/DiningCode place links: Naver Map cannot reliably
    // resolve their external POI IDs and may display "알 수 없는 장소".
    // Always pass "상호명 + 시·군·구 + 읍·면·동" as a normal search query.
    final appUri = nearbyFoodNaverAppUri(spot.name, spot.address);
    final webUri = nearbyFoodNaverWebUri(spot.name, spot.address);
    try {
      final opened = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Naver Map is not installed or the device cannot handle nmap://.
    }
    try {
      final opened = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Both app and browser unavailable.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네이버지도 검색을 열 수 없습니다.')),
      );
    }
  }

  Future<void> _recommend() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FoodRecommendationForm(place: widget.place),
    );
    if (!mounted) return;
    if (submitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('맛집을 추천했습니다. 관리자 승인 후 공개됩니다.')),
      );
      setState(() => result = _fetch());
    }
  }

  Widget _spotTile(_DiningSpot spot) {
    final scheme = Theme.of(context).colorScheme;
    final status = foodOpenState(spot.openingHours, DateTime.now().toUtc());
    final statusText = switch (status) {
      FoodOpenState.open => '영업중',
      FoodOpenState.closed => '영업종료',
      FoodOpenState.unknown => '영업시간 정보 없음',
    };
    final statusForeground = switch (status) {
      FoodOpenState.open => const Color(0xFF187A37),
      FoodOpenState.closed => const Color(0xFFC03236),
      FoodOpenState.unknown => scheme.onSurfaceVariant,
    };
    final statusBackground = switch (status) {
      FoodOpenState.open => const Color(0xFFE5F5EA),
      FoodOpenState.closed => const Color(0xFFFFECEC),
      FoodOpenState.unknown => scheme.surfaceContainerHighest,
    };
    final description = <String>[
      spot.category, spot.distanceM.toString() + 'm',
      if (spot.score != null) '점수 ' + spot.score.toString() + '점',
      if (spot.source == 'community') '회원 추천',
    ].join(' · ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerLow,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: spot.rank == null
            ? Icon(Icons.place_outlined, size: 24, color: scheme.onSurfaceVariant)
            : CircleAvatar(
                radius: 17,
                backgroundColor: scheme.primaryContainer,
                child: Text(spot.rank.toString(), style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                )),
              ),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 7,
          runSpacing: 4,
          children: [
            Text(spot.name, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: statusBackground,
              ),
              child: Text(statusText, style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: statusForeground,
              )),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description
                + (spot.address.isEmpty ? '' : '\n' + spot.address)
                + (spot.comment.isEmpty ? '' : '\n추천 이유: ' + spot.comment)
                + (status == FoodOpenState.unknown ? '' : '\n등록 영업시간 기준 · 변동 가능'),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => _openSpot(spot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: FutureBuilder<List<_DiningSpot>>(
          future: result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('주변 음식점과 카페를 자동 검색하고 있습니다.'),
                ],
              ));
            }
            if (snapshot.hasError) return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('주변맛집을 불러오지 못했습니다.'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => result = _fetch()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 불러오기'),
                ),
              ],
            ));
            final rows = snapshot.data ?? const <_DiningSpot>[];
            if (rows.isEmpty) {
              return const Center(child: Text(
                '반경 1km 내 검색된 맛집이 없습니다.',
              ));
            }
            final scored = rows.where((item) => item.score != null).toList();
            final other = rows.where((item) => item.score == null).toList();
            final muted = Theme.of(context).colorScheme.onSurfaceVariant;
            return ListView(
              children: [
                if (scored.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 5, 8, 8),
                    child: Text('맛집 점수가 확인된 곳 · 점수 높은 순',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  ...scored.map(_spotTile),
                ],
                if (other.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 15, 8, 8),
                    child: Text('그 밖의 주변 음식점 · 거리순 (맛집 순위 아님)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: muted)),
                  ),
                  ...other.map(_spotTile),
                ],
              ],
            );
          },
        ),
      ),
      const Divider(height: 12),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _recommend,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('내 맛집 추천하기'),
          ),
        ),
      ),
    ],
  );
}
