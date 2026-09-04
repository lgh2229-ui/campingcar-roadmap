import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/place.dart';
import '../models/place_review.dart';
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
    return (rows as List).map((e) => Place.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<void> addPlace(Place place) async {
    final payload = place.toSupabaseJson();
    payload['owner_id'] = _uid;
    await client.from('places').insert(payload);
  }

  @override
  Future<void> updatePlace(Place place) async {
    // RLS에서 관리자만 UPDATE 허용. 클라이언트 UI 체크만 믿지 않습니다.
    await client.from('places').update(place.toSupabaseJson()).eq('id', place.id);
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
    if (add.isNotEmpty) {
      await client.from('favorites').insert(add.map((id) => {'user_id': _uid, 'place_id': id}).toList());
    }
    if (remove.isNotEmpty) {
      await client.from('favorites').delete().eq('user_id', _uid).inFilter('place_id', remove.toList());
    }
  }

  @override
  Future<List<PlaceReview>> reviews(String placeId) async {
    final rows = await client.from('reviews_view').select().eq('place_id', placeId).order('created_at', ascending: false);
    return (rows as List).map((e) => PlaceReview.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<void> addReview({required String placeId, required String status, required String body}) async {
    await client.from('reviews').insert({
      'place_id': placeId,
      'author_id': _uid,
      'status': status,
      'body': body.trim(),
    });
    // place status는 SQL trigger가 최신 리뷰 상태로 갱신합니다.
  }

  @override
  Future<List<String>> uploadPlacePhotos(String placeId, List<File> files) async {
    final urls = <String>[];
    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      final safeExt = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : 'jpg';
      final objectPath = '$_uid/$placeId/${const Uuid().v4()}.$safeExt';
      await client.storage.from(_bucket).upload(
        objectPath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      final publicUrl = client.storage.from(_bucket).getPublicUrl(objectPath);
      await client.from('place_photos').insert({
        'place_id': placeId,
        'uploader_id': _uid,
        'storage_path': objectPath,
        'public_url': publicUrl,
      });
      urls.add(publicUrl);
    }
    return urls;
  }
}
