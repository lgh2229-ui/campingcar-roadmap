import 'dart:io';
import '../models/place.dart';
import '../models/place_review.dart';

abstract class AppDataRepository {
  Future<List<Place>> places();
  Future<void> addPlace(Place place);
  Future<void> updatePlace(Place place);
  Future<Set<String>> savedIds();
  Future<void> saveSavedIds(Set<String> ids);
  Future<List<PlaceReview>> reviews(String placeId);
  Future<void> addReview({required String placeId, required String status, required String body});
  Future<void> updateReview({required String reviewId, required String status, required String body});
  Future<void> deleteReview(String reviewId);
  Future<List<String>> uploadPlacePhotos(String placeId, List<File> files);
}
