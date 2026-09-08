import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_review_task.dart';
import '../models/app_user.dart';
import '../models/place.dart';
import '../models/place_review.dart';
import '../models/review_comment.dart';
import 'app_data_repository.dart';

class LocalRepository implements AppDataRepository {
  static const _usersKey = 'roadmap_users_flutter';
  static const _placesKey = 'roadmap_places_flutter';
  static const _savedKey = 'roadmap_saved_flutter';
  static const _sessionKey = 'roadmap_session_flutter';
  static const _reviewsKey = 'roadmap_reviews_flutter';
  static const _commentsKey = 'roadmap_review_comments_flutter';
  static const _tasksKey = 'roadmap_admin_review_tasks_flutter';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<AppUser>> users() async {
    final raw = (await _prefs).getString(_usersKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveUsers(List<AppUser> users) async => (await _prefs).setString(_usersKey, jsonEncode(users.map((e) => e.toJson()).toList()));

  @override
  Future<List<Place>> places() async {
    final raw = (await _prefs).getString(_placesKey);
    if (raw == null) return [];
    final uid = await sessionUserId() ?? '';
    final rows = (jsonDecode(raw) as List).map((e) => Place.fromJson(Map<String, dynamic>.from(e))).toList();
    final userList = await users();
    final me = userList.where((u) => u.userId == uid).firstOrNull;
    return rows.where((p) => p.isApproved || p.ownerId == uid || me?.isAdministrator == true).toList();
  }

  Future<void> savePlaces(List<Place> places) async => (await _prefs).setString(_placesKey, jsonEncode(places.map((e) => e.toJson()).toList()));

  Future<List<Place>> _allPlaces() async {
    final raw = (await _prefs).getString(_placesKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Place.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  Future<void> addPlace(Place place) async {
    place.approvalStatus = 'pending';
    final list = await _allPlaces();
    list.add(place);
    await savePlaces(list);
  }

  @override
  Future<void> updatePlace(Place place) async {
    final list = await _allPlaces();
    final i = list.indexWhere((e) => e.id == place.id);
    if (i >= 0) list[i] = place;
    await savePlaces(list);
  }

  @override
  Future<List<Place>> pendingPlaces() async => (await _allPlaces()).where((p) => p.approvalStatus == 'pending').toList();

  @override
  Future<void> approvePlace(String placeId) async {
    final list = await _allPlaces();
    final i = list.indexWhere((p) => p.id == placeId);
    if (i >= 0) list[i].approvalStatus = 'approved';
    await savePlaces(list);
  }

  @override
  Future<void> rejectPlace(String placeId) async {
    final list = await _allPlaces();
    final i = list.indexWhere((p) => p.id == placeId);
    if (i >= 0) list[i].approvalStatus = 'rejected';
    await savePlaces(list);
  }

  @override
  Future<Set<String>> savedIds() async => ((await _prefs).getStringList(_savedKey) ?? const []).toSet();
  @override
  Future<void> saveSavedIds(Set<String> ids) async => (await _prefs).setStringList(_savedKey, ids.toList());
  Future<void> setSession(String? userId) async { final p = await _prefs; if (userId == null) { await p.remove(_sessionKey); } else { await p.setString(_sessionKey, userId); } }
  Future<String?> sessionUserId() async => (await _prefs).getString(_sessionKey);

  @override
  Future<List<PlaceReview>> reviews(String placeId) async {
    final raw = (await _prefs).getString(_reviewsKey);
    if (raw == null) return [];
    final rows = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).where((e) => '${e['place_id']}' == placeId).map(PlaceReview.fromJson).toList();
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  @override
  Future<void> addReview({required String placeId, required String status, required String body}) async {
    final p = await _prefs;
    final list = p.getString(_reviewsKey) == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(p.getString(_reviewsKey)!) as List);
    final uid = await sessionUserId() ?? '';
    final me = (await users()).where((u) => u.userId == uid).firstOrNull;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    list.add({'id': id, 'place_id': placeId, 'author_id': uid, 'author_name': me?.displayName ?? uid, 'status': status, 'body': body, 'created_at': DateTime.now().toIso8601String()});
    await p.setString(_reviewsKey, jsonEncode(list));
    if (status == 'change' || status == 'bad') {
      final tasks = p.getString(_tasksKey) == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(p.getString(_tasksKey)!) as List);
      tasks.add({'id': 'task_$id', 'review_id': id, 'place_id': placeId, 'reason': status == 'bad' ? '이용불가 리뷰' : '변경 리뷰', 'handled': false, 'created_at': DateTime.now().toIso8601String()});
      await p.setString(_tasksKey, jsonEncode(tasks));
    }
  }

  @override
  Future<void> updateReview({required String reviewId, required String status, required String body}) async {
    final p = await _prefs; final raw = p.getString(_reviewsKey); if (raw == null) return;
    final list = List<dynamic>.from(jsonDecode(raw) as List); final uid = await sessionUserId() ?? '';
    final i = list.indexWhere((e) => '${(e as Map)['id']}' == reviewId && '${e['author_id']}' == uid);
    if (i < 0) throw Exception('본인이 작성한 리뷰만 수정할 수 있습니다.');
    final row = Map<String, dynamic>.from(list[i] as Map); row['status'] = status; row['body'] = body.trim(); list[i] = row;
    await p.setString(_reviewsKey, jsonEncode(list));
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    final p = await _prefs; final raw = p.getString(_reviewsKey); if (raw == null) return;
    final list = List<dynamic>.from(jsonDecode(raw) as List); final uid = await sessionUserId() ?? ''; final before = list.length;
    list.removeWhere((e) => '${(e as Map)['id']}' == reviewId && '${e['author_id']}' == uid);
    if (before == list.length) throw Exception('본인이 작성한 리뷰만 삭제할 수 있습니다.');
    await p.setString(_reviewsKey, jsonEncode(list));
  }

  @override
  Future<List<ReviewComment>> reviewComments(String reviewId) async {
    final raw = (await _prefs).getString(_commentsKey); if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).where((e) => '${e['review_id']}' == reviewId).map(ReviewComment.fromJson).toList();
  }

  @override
  Future<void> addReviewComment({required String reviewId, required String body}) async {
    final p = await _prefs; final list = p.getString(_commentsKey) == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(p.getString(_commentsKey)!) as List);
    final uid = await sessionUserId() ?? ''; final me = (await users()).where((u) => u.userId == uid).firstOrNull;
    list.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'review_id': reviewId, 'author_id': uid, 'author_name': me?.displayName ?? uid, 'body': body.trim(), 'created_at': DateTime.now().toIso8601String()});
    await p.setString(_commentsKey, jsonEncode(list));
  }

  @override
  Future<List<AdminReviewTask>> adminReviewTasks() async {
    final raw = (await _prefs).getString(_tasksKey); if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => AdminReviewTask.fromJson(Map<String, dynamic>.from(e))).where((e) => !e.handled).toList();
  }

  @override
  Future<void> completeAdminReviewTask(String taskId) async {
    final p = await _prefs; final raw = p.getString(_tasksKey); if (raw == null) return;
    final list = List<dynamic>.from(jsonDecode(raw) as List); final i = list.indexWhere((e) => '${(e as Map)['id']}' == taskId);
    if (i >= 0) { final row = Map<String, dynamic>.from(list[i] as Map); row['handled'] = true; list[i] = row; await p.setString(_tasksKey, jsonEncode(list)); }
  }

  @override
  Future<List<String>> uploadPlacePhotos(String placeId, List<File> files) async {
    final urls = files.map((e) => e.path).toList(); final list = await _allPlaces(); final i = list.indexWhere((e) => e.id == placeId);
    if (i >= 0) { list[i].photoUrls = [...list[i].photoUrls, ...urls]; await savePlaces(list); }
    return urls;
  }
}
