import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';
import '../models/place_review.dart';

/// Shared detail sheet for regular users and administrators.
class PlaceDetailSheet extends StatefulWidget {
  const PlaceDetailSheet({
    super.key,
    required this.place,
    required this.scrollController,
    required this.reviews,
    required this.initiallySaved,
    required this.isAdministrator,
    required this.onSetSaved,
    required this.onReview,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenAddress,
    required this.onPhotoTap,
    required this.photoBuilder,
    required this.reviewBuilder,
    this.reservationUrl = '',
    this.heightCompatibility,
  });

  final Place place;
  final ScrollController scrollController;
  final List<PlaceReview> reviews;
  final bool initiallySaved;
  final bool isAdministrator;
  final Future<bool> Function(bool) onSetSaved;
  final VoidCallback onReview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenAddress;
  final void Function(int) onPhotoTap;
  final Widget Function(String) photoBuilder;
  final Widget Function(PlaceReview) reviewBuilder;
  final String reservationUrl;
  final Widget? heightCompatibility;

  @override
  State<PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<PlaceDetailSheet> {
  late bool saved = widget.initiallySaved;
  bool saving = false;

  static const coreServices = <String>[
    '노지/차박', '공중화장실', '급수', '블랙탱크 비움',
  ];
  static const serviceTitles = <String, String>{
    '노지/차박': '노지 / 차박',
    '공중화장실': '화장실',
    '급수': '청수 / 급수',
    '블랙탱크 비움': '블랙탱크',
    '전기': '전기',
    '캠핑장': '캠핑장',
    '부품·용품': '부품 / 용품',
  };
  static const serviceIcons = <String, IconData>{
    '노지/차박': Icons.directions_car_outlined,
    '공중화장실': Icons.wc_outlined,
    '급수': Icons.water_drop_outlined,
    '블랙탱크 비움': Icons.delete_outline,
    '전기': Icons.bolt_outlined,
    '캠핑장': Icons.terrain_outlined,
    'A/S': Icons.build_outlined,
    '매매': Icons.directions_car_filled_outlined,
    '제작': Icons.handyman_outlined,
    '부품·용품': Icons.construction_outlined,
  };

  Color get muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get stroke => Theme.of(context).colorScheme.outlineVariant;

  Widget heading(IconData icon, String name) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 9),
          Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget panel(Widget content) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke),
        ),
        child: content,
      );

  Widget serviceCard(String service) {
    final p = widget.place;
    final isAvailable = p.services.contains(service);
    final price = (p.prices[service] ?? '').trim();
    final display = isAvailable
        ? (price.isEmpty ? '요금 확인 필요' : price)
        : '이용불가';
    final free = isAvailable && (price == '무료' || price == '0원');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stroke),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(serviceIcons[service] ?? Icons.place_outlined, color: muted, size: 19),
          const SizedBox(width: 7),
          Expanded(child: Text(
            serviceTitles[service] ?? service,
            style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600),
          )),
        ]),
        const SizedBox(height: 10),
        Text(display,
            style: TextStyle(
              fontSize: free ? 17 : 14,
              height: 1.4,
              fontWeight: isAvailable ? FontWeight.w700 : FontWeight.w500,
              color: isAvailable
                  ? (free ? Theme.of(context).colorScheme.primary : null)
                  : muted,
            )),
      ]),
    );
  }

  Widget infoRow(IconData icon, String title, String detail,
      {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 20, color: muted),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 4),
              Text(detail,
                  style: const TextStyle(
                      fontSize: 14, height: 1.45, fontWeight: FontWeight.w500)),
            ],
          )),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Icon(Icons.chevron_right, size: 18, color: muted),
            ),
        ]),
      ),
    );
  }

  Future<void> openLink(String raw) async {
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://' + raw);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('예약 페이지를 열 수 없습니다.')),
      );
    }
  }

  Future<void> callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화 앱을 열 수 없습니다.')),
      );
    }
  }

  Future<void> toggleSaved() async {
    if (saving) return;
    setState(() => saving = true);
    final target = !saved;
    final success = await widget.onSetSaved(target);
    if (!mounted) return;
    setState(() {
      if (success) saved = target;
      saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final name = p.name.replaceFirst(
      RegExp(r'^\[(승인 대기|승인 반려)\]\s*'), '',
    );
    final note = p.note
        .split('\n')
        .where((line) => !line.startsWith('[예약링크]'))
        .join('\n')
        .replaceAll(r'\n', '\n')
        .trim();
    final extras = p.services.where((service) => !coreServices.contains(service)).toList();
    final services = <String>[...coreServices, ...extras];
    final hasOperation = p.hours.isNotEmpty ||
        p.reservation.isNotEmpty || p.phone.isNotEmpty || p.maxHeightMm != null;
    final created = p.createdAt?.toLocal();
    final createdLabel = created == null ? '' :
        created.year.toString() + '.' +
        created.month.toString().padLeft(2, '0') + '.' +
        created.day.toString().padLeft(2, '0');

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('장소 상세정보',
              style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
          ),
        ]),
        const SizedBox(height: 2),
        Text(name,
            style: const TextStyle(
                fontSize: 23, height: 1.28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (p.services.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.services.take(4).map((service) => Chip(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
              side: BorderSide(color: stroke),
              visualDensity: VisualDensity.compact,
              label: Text(serviceTitles[service] ?? service,
                  style: const TextStyle(fontSize: 12)),
            )).toList(),
          ),
        if (p.address.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 20, color: muted),
            const SizedBox(width: 7),
            Expanded(child: InkWell(
              onTap: widget.onOpenAddress,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(p.address,
                    style: TextStyle(fontSize: 13, height: 1.45, color: muted)),
              ),
            )),
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              tooltip: '주소 복사',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: p.address));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('주소를 복사했습니다.')),
                );
              },
            ),
          ]),
        ],
        if (p.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: p.photoUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (_, index) => InkWell(
                onTap: () => widget.onPhotoTap(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.photoBuilder(p.photoUrls[index]),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        heading(Icons.fact_check_outlined, '이용 가능 시설'),
        LayoutBuilder(builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: services.map((service) =>
              SizedBox(width: itemWidth, child: serviceCard(service)),
            ).toList(),
          );
        }),
        const SizedBox(height: 24),
        heading(Icons.schedule_outlined, '운영 정보'),
        panel(Column(
          children: [
            if (!hasOperation)
              Text('운영 정보가 아직 등록되지 않았습니다.',
                  style: TextStyle(color: muted)),
            if (p.hours.isNotEmpty) infoRow(Icons.access_time, '운영시간', p.hours),
            if (p.hours.isNotEmpty && p.reservation.isNotEmpty)
              Divider(color: stroke, height: 16),
            if (p.reservation.isNotEmpty)
              infoRow(Icons.event_available_outlined, '예약 안내', p.reservation),
            if (widget.reservationUrl.isNotEmpty) Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openLink(widget.reservationUrl),
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('예약 페이지 열기'),
              ),
            ),
            if (p.phone.isNotEmpty) ...[
              if (p.hours.isNotEmpty || p.reservation.isNotEmpty)
                Divider(color: stroke, height: 16),
              infoRow(Icons.phone_outlined, '문의전화', p.phone,
                  onTap: () => callPhone(p.phone)),
            ],
            if (p.maxHeightMm != null) ...[
              if (p.hours.isNotEmpty || p.reservation.isNotEmpty || p.phone.isNotEmpty)
                Divider(color: stroke, height: 16),
              infoRow(Icons.height, '진입 높이 제한',
                  (p.maxHeightMm! / 1000).toStringAsFixed(2) + 'm'),
              if (widget.heightCompatibility != null) widget.heightCompatibility!,
            ],
          ],
        )),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 24),
          heading(Icons.info_outline, '이용 안내 및 주의사항'),
          panel(Text(note, style: const TextStyle(fontSize: 14, height: 1.65))),
        ],
        if (!p.isApproved) ...[
          const SizedBox(height: 16),
          panel(Text(
            p.isPending
                ? '관리자가 등록 내용을 확인 중입니다. 승인되면 지도에 공개됩니다.'
                : '등록 상태를 확인해주세요.',
          )),
        ],
        if (p.isApproved) ...[
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: saving ? null : toggleSaved,
              icon: Icon(saved ? Icons.star : Icons.star_border),
              label: Text(saved ? '저장됨' : '저장하기'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.tonalIcon(
              onPressed: widget.onReview,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('검증 리뷰'),
            )),
          ]),
          if (widget.isAdministrator) ...[
            const SizedBox(height: 24),
            Row(children: [
              Icon(Icons.admin_panel_settings_outlined, size: 18, color: muted),
              const SizedBox(width: 7),
              Text('관리자 전용',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: muted)),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('장소 수정'),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: widget.onDelete,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('장소 삭제'),
              )),
            ]),
          ],
          const SizedBox(height: 22),
          Divider(color: stroke),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: heading(Icons.reviews_outlined, '검증 리뷰')),
            Text(widget.reviews.length.toString() + '건',
                style: TextStyle(fontSize: 12, color: muted)),
          ]),
          if (widget.reviews.isEmpty) Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Icon(Icons.chat_bubble_outline, color: muted, size: 30),
              const SizedBox(height: 10),
              Text('아직 등록된 검증 리뷰가 없습니다.',
                  style: TextStyle(fontSize: 13, color: muted)),
            ]),
          ),
          ...widget.reviews.map(widget.reviewBuilder),
        ],
        if (p.ownerNickname.trim().isNotEmpty || createdLabel.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '등록자 ' +
                (p.ownerNickname.trim().isEmpty ? '닉네임 없음' : p.ownerNickname) +
                (createdLabel.isEmpty ? '' : '  ·  ' + createdLabel),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ],
    );
  }
}
