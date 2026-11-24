import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';

/// Public DiningCode points, filtered on the server by a strict 1 km
/// straight-line radius from the saved place coordinates and capped at 20.
/// The number shown is this filtered *score order*, not a claim that
/// DiningCode published an official 1 km ranking.
class NearbyDiningCodeSection extends StatefulWidget {
  const NearbyDiningCodeSection({super.key, required this.place});
  final Place place;

  @override
  State<NearbyDiningCodeSection> createState() =>
      _NearbyDiningCodeSectionState();
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
  });

  final int rank;
  final String name;
  final String category;
  final String address;
  final int? score;
  final int distanceM;
  final String url;

  factory _DiningSpot.fromJson(Map<String, dynamic> row) => _DiningSpot(
    rank: (row['rank'] as num).toInt(),
    name: (row['name'] ?? '').toString(),
    category: (row['category'] ?? '').toString(),
    address: (row['address'] ?? '').toString(),
    score: (row['diningcode_score'] as num?)?.toInt(),
    distanceM: (row['distance_m'] as num).toInt(),
    url: (row['diningcode_url'] ?? '').toString(),
  );
}

class _NearbyDiningCodeSectionState extends State<NearbyDiningCodeSection> {
  late Future<List<_DiningSpot>> result = _fetch();

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
    final data = await Supabase.instance.client.rpc(
      'nearby_diningcode_top20',
      params: <String, dynamic>{
        'p_lat': widget.place.latitude,
        'p_lon': widget.place.longitude,
      },
    );
    if (data is! List) return const <_DiningSpot>[];
    return data.whereType<Map>().map((raw) =>
        _DiningSpot.fromJson(Map<String, dynamic>.from(raw))).toList();
  }

  String get _searchUrl {
    final parts = widget.place.address.split(' ');
    final area = parts.length > 2
        ? parts.take(3).join(' ')
        : widget.place.address;
    return Uri.https('www.diningcode.com', '/list.dc',
        <String, String>{'query': area + ' 맛집'}).toString();
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('맛집 페이지를 열 수 없습니다.')),
      );
    }
  }

  Widget _spotTile(_DiningSpot spot) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerLow,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: scheme.primaryContainer,
          child: Text(spot.rank.toString(), style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold,
            color: scheme.onPrimaryContainer,
          )),
        ),
        title: Text(spot.name, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700,
        )),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            spot.category + ' · ' + spot.distanceM.toString() + 'm' +
                (spot.score == null ? '' : ' · 다코 ' + spot.score.toString() + '점') +
                (spot.address.isEmpty ? '' : '\n' + spot.address),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
        isThreeLine: spot.address.isNotEmpty,
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => _openUrl(spot.url),
      ),
    );
  }

  void _openAll(List<_DiningSpot> rows) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('주변맛집', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: 4),
            const Text('다이닝코드 점수순 · 직선거리 1km · 최대 20곳',
              style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Expanded(child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, index) => _spotTile(rows[index]),
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_DiningSpot>>(
      future: result,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rows = snapshot.data ?? const <_DiningSpot>[];
        if (snapshot.hasError || rows.isEmpty) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('반경 1km 내 등록된 다이닝코드 맛집 목록이 없습니다.',
              style: TextStyle(fontSize: 12)),
            TextButton.icon(
              onPressed: () => _openUrl(_searchUrl),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('다이닝코드에서 주변 맛집 검색'),
            ),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('다이닝코드 점수순 · 직선거리 1km · ' +
              rows.length.toString() + '곳 (최대 20곳)',
            style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.take(3).map(_spotTile),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openAll(rows),
              icon: const Icon(Icons.list_alt_outlined, size: 18),
              label: Text('전체 ' + rows.length.toString() + '곳 보기'),
            ),
          ),
        ]);
      },
    );
  }
}
