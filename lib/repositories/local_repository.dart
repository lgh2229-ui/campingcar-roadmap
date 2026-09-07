import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/place.dart';
import '../models/place_review.dart';
import 'app_data_repository.dart';

class LocalRepository implements AppDataRepository {
  static const _usersKey = 'roadmap_users_flutter';
  static const _placesKey = 'roadmap_places_flutter';
  static const _savedKey = 'roadmap_saved_flutter';
  static const _sessionKey = 'roadmap_session_flutter';
  static const _reviewsKey = 'roadmap_reviews_flutter';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<AppUser>> users() async {
    final p = await _prefs;
    final raw = p.getString(_usersKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveUsers(List<AppUser> users) async {
    final p = await _prefs;
    await p.setString(_usersKey, jsonEncode(users.map((e) => e.toJson()).toList()));
  }

  @override
  Future<List<Place>> places() async {
    final p = await _prefs;
    final raw = p.getString(_placesKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Place.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> savePlaces(List<Place> places) async {
    final p = await _prefs;
    await p.setString(_placesKey, jsonEncode(places.map((e) => e.toJson()).toList()));
  }

  @override
  Future<void> addPlace(Place place) async {
    final list = await places();
    list.add(place);
    await savePlaces(list);
  }

  @override
  Future<void> updatePlace(Place place) async {
    final list = await places();
    final i = list.indexWhere((e) => e.id == place.id);
    if (i >= 0) list[i] = place;
    await savePlaces(list);
  }

  @override
  Future<Set<String>> savedIds() async {
    final p = await _prefs;
    return (p.getStringList(_savedKey) ?? const []).toSet();
  }

  @override
  Future<void> saveSavedIds(Set<String> ids) async {
    final p = await _prefs;
    await p.setStringList(_savedKey, ids.toList());
  }

  Future<void> setSession(String? userId) async {
    final p = await _prefs;
    if (userId == null) {
      await p.remove(_sessionKey);
    } else {
      await p.setString(_sessionKey, userId);
    }
  }

  Future<String?> sessionUserId() async => (await _prefs).getString(_sessionKey);

  @override
  Future<List<PlaceReview>> reviews(String placeId) async {
    final raw = (await _prefs).getString(_reviewsKey);
    if (raw == null) return [];
    final rows = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => '${e['place_id']}' == placeId)
        .map(PlaceReview.fromJson)
        .toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  @override
  Future<void> addReview({required String placeId, required String status, required String body}) async {
    final p = await _prefs;
    final raw = p.getString(_reviewsKey);
    final list = raw == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(raw) as List);
    final uid = await sessionUserId() ?? '';
    list.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'place_id': placeId,
      'author_id': uid,
      'author_name': uid,
      'status': status,
      'body': body,
      'created_at': DateTime.now().toIso8601String(),
    });
    await p.setString(_reviewsKey, jsonEncode(list));
  }

  @override
  Future<void> updateReview({required String reviewId, required String status, required String body}) async {
    final p = await _prefs;
    final raw = p.getString(_reviewsKey);
    if (raw == null) return;
    final list = List<dynamic>.from(jsonDecode(raw) as List);
    final uid = await sessionUserId() ?? '';
    final i = list.indexWhere((e) => '${(e as Map)['id']}' == reviewId && '${e['author_id']}' == uid);
    if (i < 0) throw Exception('본인이 작성한 리뷰만 수정할 수 있습니다.');
    final row = Map<String, dynamic>.from(list[i] as Map);
    row['status'] = status;
    row['body'] = body.trim();
    list[i] = row;
    await p.setString(_reviewsKey, jsonEncode(list));
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    final p = await _prefs;
    final raw = p.getString(_reviewsKey);
    if (raw == null) return;
    final list = List<dynamic>.from(jsonDecode(raw) as List);
    final uid = await sessionUserId() ?? '';
    final before = list.length;
    list.removeWhere((e) => '${(e as Map)['id']}' == reviewId && '${e['author_id']}' == uid);
    if (before == list.length) throw Exception('본인이 작성한 리뷰만 삭제할 수 있습니다.');
    await p.setString(_reviewsKey, jsonEncode(list));
  }

  @override
  Future<List<String>> uploadPlacePhotos(String placeId, List<File> files) async {
    final urls = files.map((e) => e.path).toList();
    final list = await places();
    final i = list.indexWhere((e) => e.id == placeId);
    if (i >= 0) {
      list[i].photoUrls = [...list[i].photoUrls, ...urls];
      await savePlaces(list);
    }
    return urls;
  }
}
