import 'dart:io';
import '../models/admin_review_task.dart';
import '../models/place.dart';
import '../models/place_review.dart';
import '../models/review_comment.dart';

abstract class AppDataRepository {
  Future<List<Place>> places();
  Future<void> addPlace(Place place);
  Future<void> updatePlace(Place place);
  Future<List<Place>> pendingPlaces();
  Future<void> approvePlace(String placeId);
  Future<void> rejectPlace(String placeId);
  Future<Set<String>> savedIds();
  Future<void> saveSavedIds(Set<String> ids);
  Future<List<PlaceReview>> reviews(String placeId);
  Future<void> addReview({required String placeId, required String status, required String body});
  Future<void> updateReview({required String reviewId, required String status, required String body});
  Future<void> deleteReview(String reviewId);
  Future<List<ReviewComment>> reviewComments(String reviewId);
  Future<void> addReviewComment({required String reviewId, required String body});
  Future<List<AdminReviewTask>> adminReviewTasks();
  Future<void> completeAdminReviewTask(String taskId);
  Future<List<String>> uploadPlacePhotos(String placeId, List<File> files);
}
