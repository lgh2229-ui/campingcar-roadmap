import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Reviews for a nearby attraction (separate from the registered base place).
class ActivitySpotReviewSheet extends StatefulWidget {
  const ActivitySpotReviewSheet({super.key, required this.placeId, required this.activity, required this.spotKey, required this.spotName});
  final String placeId, activity, spotKey, spotName;
  @override
  State<ActivitySpotReviewSheet> createState() => _ActivitySpotReviewSheetState();
}

class _ActivitySpotReviewSheetState extends State<ActivitySpotReviewSheet> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _reviews = [];
  List<XFile> _photos = [];
  bool _loading = true, _composing = false, _saving = false;
  String? _error;
  SupabaseClient get _db => Supabase.instance.client;

  @override void initState() { super.initState(); _reload(); }
  @override void dispose() { _text.dispose(); super.dispose(); }

  void _notice(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reload() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await _db.from('activity_spot_reviews')
        .select('id,author_id,author_name,body,photo_urls,created_at')
        .eq('place_id', widget.placeId).eq('activity', widget.activity)
        .eq('spot_key', widget.spotKey).order('created_at', ascending: false);
      if (mounted) setState(() {
        _reviews = (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = '리뷰를 불러오지 못했습니다.'; _loading = false; });
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1400, maxHeight: 1400);
      if (!mounted || files.isEmpty) return;
      final selected = <XFile>[..._photos];
      for (final file in files) {
        if (selected.length == 3) break;
        if (!selected.any((item) => item.path == file.path)) selected.add(file);
      }
      if (files.length > 3 - _photos.length) _notice('사진은 최대 3장까지 첨부할 수 있습니다.');
      setState(() => _photos = selected);
    } catch (_) { _notice('사진을 선택하지 못했습니다. 갤러리 권한을 확인해주세요.'); }
  }

  Future<void> _submit() async {
    final body = _text.text.trim();
    if (_saving) return;
    if (body.isEmpty) { _notice('다녀온 소감을 입력해주세요.'); return; }
    if (body.length > 500) { _notice('소감은 500자 이내로 작성해주세요.'); return; }
    final user = _db.auth.currentUser;
    if (user == null) { _notice('후기를 작성하려면 로그인해야 합니다.'); return; }
    setState(() => _saving = true);
    try {
      final urls = <String>[];
      for (final photo in _photos) {
        final file = File(photo.path);
        if (await file.length() > 5 * 1024 * 1024) throw StateError('사진 한 장은 5MB 이하여야 합니다.');
        final name = photo.name.toLowerCase();
        final ext = name.endsWith('.png') ? 'png' : name.endsWith('.webp') ? 'webp' : 'jpg';
        final type = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
        final path = user.id + '/activity-reviews/' + const Uuid().v4() + '.' + ext;
        await _db.storage.from('place-photos').upload(path, file,
          fileOptions: FileOptions(contentType: type, cacheControl: '3600', upsert: false));
        urls.add(_db.storage.from('place-photos').getPublicUrl(path));
      }
      await _db.from('activity_spot_reviews').insert({
        'place_id': widget.placeId, 'activity': widget.activity,
        'spot_key': widget.spotKey, 'spot_name': widget.spotName,
        'author_id': user.id, 'body': body, 'photo_urls': urls,
      });
      if (!mounted) return;
      _text.clear();
      setState(() { _photos = []; _composing = false; });
      await _reload();
      _notice('후기가 등록되었습니다.');
    } catch (e) {
      _notice(e is StateError ? e.message.toString() : '후기 저장에 실패했습니다. 로그인 상태와 사진 용량을 확인해주세요.');
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final sure = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('리뷰 삭제'), content: const Text('작성한 후기를 삭제할까요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
      ]));
    if (sure != true) return;
    try {
      await _db.from('activity_spot_reviews').delete()
        .eq('id', review['id'].toString()).eq('author_id', user.id);
      await _reload(); _notice('후기가 삭제되었습니다.');
    } catch (_) { _notice('후기를 삭제하지 못했습니다.'); }
  }


  Future<void> _editReview(Map<String, dynamic> review) async {
    final user = _db.auth.currentUser;
    if (user == null || user.id != review['author_id']) return;
    final original = (review['body'] ?? '').toString();
    final controller = TextEditingController(text: original);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('내 후기 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '방문 소감을 수정해주세요.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(dialog).showSnackBar(
                  const SnackBar(content: Text('수정할 내용을 입력해주세요.')),
                );
                return;
              }
              Navigator.pop(dialog, value);
            },
            child: const Text('수정 완료'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || updated == null || updated == original.trim()) return;
    try {
      final result = await _db.from('activity_spot_reviews')
        .update({'body': updated})
        .eq('id', review['id'].toString())
        .eq('author_id', user.id)
        .select('id');
      if ((result as List).isEmpty) {
        throw StateError('본인이 작성한 후기만 수정할 수 있습니다.');
      }
      await _reload();
      _notice('후기를 수정했습니다.');
    } catch (_) {
      _notice('후기를 수정하지 못했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _showImage(String url) => showDialog<void>(context: context,
    builder: (ctx) => Dialog(child: SizedBox(height: MediaQuery.sizeOf(ctx).height * .56,
      child: Stack(children: [
        Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('사진을 불러오지 못했습니다.')))),
        Positioned(right: 2, top: 2, child: IconButton(
          icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))),
      ]))));

  Widget _reviewTile(Map<String, dynamic> review) {
    final scheme = Theme.of(context).colorScheme;
    final photos = review['photo_urls'] is List
      ? List<String>.from(review['photo_urls'] as List) : <String>[];
    final date = DateTime.tryParse((review['created_at'] ?? '').toString())?.toLocal();
    final stamp = date == null ? '' : date.year.toString() + '.' +
      date.month.toString().padLeft(2, '0') + '.' + date.day.toString().padLeft(2, '0');
    final nickname = (review['author_name'] ?? '회원').toString().trim();
    final mine = _db.auth.currentUser?.id == review['author_id'];
    return Container(margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 15, child: Text(nickname.isEmpty ? '회' : nickname.substring(0, 1))),
          const SizedBox(width: 8),
          Expanded(child: Text(nickname.isEmpty ? '회원' : nickname,
            style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(stamp, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          if (mine) ...[
            IconButton(tooltip: '내 후기 수정', visualDensity: VisualDensity.compact,
              onPressed: () => _editReview(review),
              icon: const Icon(Icons.edit_outlined, size: 18)),
            IconButton(tooltip: '내 후기 삭제', visualDensity: VisualDensity.compact,
              onPressed: () => _deleteReview(review),
              icon: const Icon(Icons.delete_outline, size: 18)),
          ],
        ]),
        const SizedBox(height: 8),
        Text((review['body'] ?? '').toString(),
          style: const TextStyle(fontSize: 13.5, height: 1.5)),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(height: 88, child: ListView.separated(scrollDirection: Axis.horizontal,
            itemCount: photos.length, separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) => InkWell(onTap: () => _showImage(photos[i]),
              child: ClipRRect(borderRadius: BorderRadius.circular(9),
                child: Image.network(photos[i], height: 88, width: 88, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 88,
                    child: Icon(Icons.broken_image_outlined)))))),
        ],
      ]));
  }

  Widget _composer() {
    final scheme = Theme.of(context).colorScheme;
    return Container(margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('방문 후기 작성', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        TextField(controller: _text, maxLength: 500, maxLines: 4,
          decoration: const InputDecoration(hintText: '직접 방문해 본 소감이나 이용 팁을 공유해주세요.',
            border: OutlineInputBorder(), filled: true)),
        if (_photos.isNotEmpty) SizedBox(height: 76, child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: _photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.file(File(_photos[i].path), width: 74, height: 74, fit: BoxFit.cover)),
            Positioned(right: 0, top: 0, child: InkWell(
              onTap: () => setState(() => _photos.removeAt(i)),
              child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 15)))),
          ]))),
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [
          OutlinedButton.icon(onPressed: _saving || _photos.length >= 3 ? null : _pickPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text('사진 추가 (' + _photos.length.toString() + '/3)')),
          TextButton(onPressed: _saving ? null : () => setState(() {
            _composing = false; _photos = []; _text.clear();
          }), child: const Text('취소')),
          FilledButton.icon(onPressed: _saving ? null : _submit,
            icon: _saving ? const SizedBox(width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_outlined, size: 17), label: const Text('등록')),
        ]),
      ]));
  }

  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(top: false, child: Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(height: (MediaQuery.sizeOf(context).height - keyboard) * .84,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
            child: Row(children: [
              Icon(Icons.rate_review_outlined, color: scheme.primary),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.spotName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('방문 후기 · ' + _reviews.length.toString() + '건',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ])),
              IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
            ])),
          const Divider(height: 1),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              if (_db.auth.currentUser != null && !_composing)
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: () => setState(() => _composing = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('다녀온 소감·사진 올리기'))),
              if (_composing) _composer(),
              const SizedBox(height: 12),
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(20),
                child: CircularProgressIndicator())),
              if (_error != null) Center(child: Column(children: [
                Text(_error!), TextButton(onPressed: _reload, child: const Text('다시 시도'))])),
              if (!_loading && _error == null && _reviews.isEmpty)
                const Padding(padding: EdgeInsets.all(22), child: Column(children: [
                  Icon(Icons.forum_outlined, size: 35),
                  SizedBox(height: 10), Text('아직 등록된 후기가 없습니다.'),
                  SizedBox(height: 4), Text('첫 방문 소감과 사진을 남겨주세요.',
                    style: TextStyle(fontSize: 12)),
                ])),
              if (!_loading && _error == null) ..._reviews.map(_reviewTile),
            ])),
        ]))));
  }
}
