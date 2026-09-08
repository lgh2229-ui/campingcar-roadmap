import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/admin_review_task.dart';
import '../models/place.dart';
import '../models/place_review.dart';
import '../models/review_comment.dart';
import 'app_data_repository.dart';

class SupabaseRepository implements AppDataRepository {
  SupabaseRepository(this.client);
  final SupabaseClient client;
  static const _bucket = 'place-photos';

  String get _uid {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('로그인이 필요합니다.');
    return id;
  }

  @override
  Future<List<Place>> places() async {
    final rows = await client.from('places_view').select().order('created_at', ascending: false);
    final places = (rows as List).map((e) => Place.fromJson(Map<String, dynamic>.from(e))).toList();
    if (places.isEmpty) return places;
    final photoRows = await client.from('place_photos').select('place_id, public_url').inFilter('place_id', places.map((e) => e.id).toList());
    final byPlace = <String, List<String>>{};
    for (final row in photoRows as List) {
      final placeId = '${row['place_id']}';
      final url = '${row['public_url'] ?? ''}'.trim();
      if (url.isNotEmpty) byPlace.putIfAbsent(placeId, () => <String>[]).add(url);
    }
    for (final place in places) {
      place.photoUrls = byPlace[place.id] ?? place.photoUrls;
      if (place.isPending && place.ownerId == _uid) place.name = '[승인 대기] ${place.name}';
      if (place.approvalStatus == 'rejected' && place.ownerId == _uid) place.name = '[승인 반려] ${place.name}';
    }
    return places;
  }

  @override
  Future<void> addPlace(Place place) async {
    final payload = place.toSupabaseJson();
    payload['owner_id'] = _uid;
    payload['approval_status'] = 'pending';
    await client.from('places').insert(payload);
  }

  @override
  Future<void> updatePlace(Place place) async => client.from('places').update(place.toSupabaseJson()).eq('id', place.id);

  @override
  Future<List<Place>> pendingPlaces() async {
    final rows = await client.from('places_view').select().eq('approval_status', 'pending').order('created_at', ascending: false);
    return (rows as List).map((e) => Place.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<void> approvePlace(String placeId) async {
    await client.from('places').update({'approval_status': 'approved', 'approved_at': DateTime.now().toIso8601String(), 'approved_by': _uid}).eq('id', placeId);
  }

  @override
  Future<void> rejectPlace(String placeId) async {
    await client.from('places').update({'approval_status': 'rejected', 'approved_at': null, 'approved_by': _uid}).eq('id', placeId);
  }

  @override
  Future<Set<String>> savedIds() async {
    final rows = await client.from('favorites').select('place_id').eq('user_id', _uid);
    return (rows as List).map((e) => '${e['place_id']}').toSet();
  }

  @override
  Future<void> saveSavedIds(Set<String> ids) async {
    final existing = await savedIds();
    final add = ids.difference(existing);
    final remove = existing.difference(ids);
    if (add.isNotEmpty) await client.from('favorites').insert(add.map((id) => {'user_id': _uid, 'place_id': id}).toList());
    if (remove.isNotEmpty) await client.from('favorites').delete().eq('user_id', _uid).inFilter('place_id', remove.toList());
  }

  @override
  Future<List<PlaceReview>> reviews(String placeId) async {
    final rows = await client.from('reviews_view').select().eq('place_id', placeId).order('created_at', ascending: false);
    return (rows as List).map((e) => PlaceReview.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<void> addReview({required String placeId, required String status, required String body}) async {
    await client.from('reviews').insert({'place_id': placeId, 'author_id': _uid, 'status': status, 'body': body.trim()});
  }

  @override
  Future<void> updateReview({required String reviewId, required String status, required String body}) async {
    final updated = await client.from('reviews').update({'status': status, 'body': body.trim()}).eq('id', reviewId).eq('author_id', _uid).select('id');
    if ((updated as List).isEmpty) throw Exception('본인이 작성한 리뷰만 수정할 수 있습니다.');
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    final deleted = await client.from('reviews').delete().eq('id', reviewId).eq('author_id', _uid).select('id');
    if ((deleted as List).isEmpty) throw Exception('본인이 작성한 리뷰만 삭제할 수 있습니다.');
  }

  @override
  Future<List<ReviewComment>> reviewComments(String reviewId) async {
    final rows = await client.from('review_comments').select().eq('review_id', reviewId).order('created_at');
    return (rows as List).map((e) => ReviewComment.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<void> addReviewComment({required String reviewId, required String body}) async {
    if (body.trim().isEmpty) throw Exception('댓글 내용을 입력해주세요.');
    await client.from('review_comments').insert({'review_id': reviewId, 'author_id': _uid, 'body': body.trim()});
  }

  @override
  Future<List<AdminReviewTask>> adminReviewTasks() async {
    final rows = await client.from('review_admin_tasks').select().eq('handled', false).order('created_at', ascending: false);
    return (rows as List).map((e) => AdminReviewTask.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<void> completeAdminReviewTask(String taskId) async {
    await client.from('review_admin_tasks').update({'handled': true, 'handled_by': _uid, 'handled_at': DateTime.now().toIso8601String()}).eq('id', taskId);
  }

  @override
  Future<List<String>> uploadPlacePhotos(String placeId, List<File> files) async {
    final urls = <String>[];
    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      final safeExt = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : 'jpg';
      final objectPath = '$_uid/$placeId/${const Uuid().v4()}.$safeExt';
      await client.storage.from(_bucket).upload(objectPath, file, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
      final publicUrl = client.storage.from(_bucket).getPublicUrl(objectPath);
      await client.from('place_photos').insert({'place_id': placeId, 'uploader_id': _uid, 'storage_path': objectPath, 'public_url': publicUrl});
      urls.add(publicUrl);
    }
    return urls;
  }
}
