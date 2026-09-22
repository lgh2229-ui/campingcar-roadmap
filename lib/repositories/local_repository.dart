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
  static const _usersKey='roadmap_users_flutter',_placesKey='roadmap_places_flutter',_savedKey='roadmap_saved_flutter',_sessionKey='roadmap_session_flutter',_reviewsKey='roadmap_reviews_flutter',_commentsKey='roadmap_review_comments_flutter',_tasksKey='roadmap_admin_review_tasks_flutter';
  Future<SharedPreferences> get _prefs=>SharedPreferences.getInstance();
  Future<List<AppUser>> users() async {final raw=(await _prefs).getString(_usersKey);if(raw==null)return[];return(jsonDecode(raw)as List).map((e)=>AppUser.fromJson(Map<String,dynamic>.from(e))).toList();}
  Future<void> saveUsers(List<AppUser> u)async=>(await _prefs).setString(_usersKey,jsonEncode(u.map((e)=>e.toJson()).toList()));
  @override Future<List<Place>> places()async{final raw=(await _prefs).getString(_placesKey);if(raw==null)return[];final uid=await sessionUserId()??'',rows=(jsonDecode(raw)as List).map((e)=>Place.fromJson(Map<String,dynamic>.from(e))).toList(),us=await users();final me=us.where((u)=>u.userId==uid).firstOrNull;return rows.where((p)=>p.isApproved||p.ownerId==uid||me?.isAdministrator==true).toList();}
  Future<void> savePlaces(List<Place> p)async=>(await _prefs).setString(_placesKey,jsonEncode(p.map((e)=>e.toJson()).toList()));
  Future<List<Place>> _allPlaces()async{final raw=(await _prefs).getString(_placesKey);if(raw==null)return[];return(jsonDecode(raw)as List).map((e)=>Place.fromJson(Map<String,dynamic>.from(e))).toList();}
  @override Future<void> addPlace(Place p)async{p.approvalStatus='pending';p.createdAt??=DateTime.now();final l=await _allPlaces();l.add(p);await savePlaces(l);}
  @override Future<void> updatePlace(Place p)async{p.updatedAt=DateTime.now();final l=await _allPlaces(),i=l.indexWhere((e)=>e.id==p.id);if(i>=0)l[i]=p;await savePlaces(l);}
  @override Future<void> deletePlace(String id)async{final l=await _allPlaces();l.removeWhere((e)=>e.id==id);await savePlaces(l);}
  @override Future<List<Place>> pendingPlaces()async=>(await _allPlaces()).where((p)=>p.approvalStatus=='pending').toList();
  @override Future<void> approvePlace(String id)async{final l=await _allPlaces(),i=l.indexWhere((p)=>p.id==id);if(i>=0)l[i].approvalStatus='approved';await savePlaces(l);}
  @override Future<void> rejectPlace(String id)async{final l=await _allPlaces(),i=l.indexWhere((p)=>p.id==id);if(i>=0)l[i].approvalStatus='rejected';await savePlaces(l);}
  @override Future<Set<String>> savedIds()async=>((await _prefs).getStringList(_savedKey)??const[]).toSet();
  @override Future<void> saveSavedIds(Set<String> ids)async=>(await _prefs).setStringList(_savedKey,ids.toList());
  Future<void> setSession(String? id)async{final p=await _prefs;if(id==null){await p.remove(_sessionKey);}else{await p.setString(_sessionKey,id);}}
  Future<String?> sessionUserId()async=>(await _prefs).getString(_sessionKey);
  @override Future<List<PlaceReview>> reviews(String placeId)async{final raw=(await _prefs).getString(_reviewsKey);if(raw==null)return[];final rows=(jsonDecode(raw)as List).map((e)=>Map<String,dynamic>.from(e)).where((e)=>'${e['place_id']}'==placeId).map(PlaceReview.fromJson).toList();rows.sort((a,b)=>b.createdAt.compareTo(a.createdAt));return rows;}
  @override Future<void> addReview({required String placeId,required String status,required String body})async{final p=await _prefs,raw=p.getString(_reviewsKey),rows=raw==null?<Map<String,dynamic>>[]:List<Map<String,dynamic>>.from((jsonDecode(raw)as List).map((e)=>Map<String,dynamic>.from(e)));rows.add({'id':DateTime.now().microsecondsSinceEpoch.toString(),'place_id':placeId,'author_id':await sessionUserId()??'','author_name':await sessionUserId()??'','status':status,'body':body,'created_at':DateTime.now().toIso8601String()});await p.setString(_reviewsKey,jsonEncode(rows));}
  @override Future<void> updateReview({required String reviewId,required String status,required String body})async{final p=await _prefs,rows=jsonDecode(p.getString(_reviewsKey)??'[]')as List;for(final x in rows){if('${x['id']}'==reviewId){x['status']=status;x['body']=body;}}await p.setString(_reviewsKey,jsonEncode(rows));}
  @override Future<void> deleteReview(String id)async{final p=await _prefs,rows=jsonDecode(p.getString(_reviewsKey)??'[]')as List;rows.removeWhere((x)=>'${x['id']}'==id);await p.setString(_reviewsKey,jsonEncode(rows));}
  @override Future<List<ReviewComment>> reviewComments(String id)async{final raw=(await _prefs).getString(_commentsKey);if(raw==null)return[];return(jsonDecode(raw)as List).map((e)=>Map<String,dynamic>.from(e)).where((e)=>'${e['review_id']}'==id).map(ReviewComment.fromJson).toList();}
  @override Future<void> addReviewComment({required String reviewId,required String body})async{final p=await _prefs,rows=jsonDecode(p.getString(_commentsKey)??'[]')as List;rows.add({'id':DateTime.now().microsecondsSinceEpoch.toString(),'review_id':reviewId,'author_id':await sessionUserId()??'','author_name':await sessionUserId()??'','body':body,'created_at':DateTime.now().toIso8601String()});await p.setString(_commentsKey,jsonEncode(rows));}
  @override Future<List<AdminReviewTask>> adminReviewTasks({bool includeHandled=false})async{final raw=(await _prefs).getString(_tasksKey);if(raw==null)return[];final rows=(jsonDecode(raw)as List).map((e)=>AdminReviewTask.fromJson(Map<String,dynamic>.from(e))).toList();return includeHandled?rows:rows.where((e)=>!e.handled).toList();}
  @override Future<void> completeAdminReviewTask(String id)async{}
  @override Future<List<String>> uploadPlacePhotos(String placeId,List<File> files)async=>files.map((e)=>e.path).toList();
}
