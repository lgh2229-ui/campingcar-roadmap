class AdminReviewTask {
  AdminReviewTask({
    required this.id,
    required this.reviewId,
    required this.placeId,
    required this.reason,
    required this.handled,
    required this.createdAt,
  });

  final String id;
  final String reviewId;
  final String placeId;
  final String reason;
  final bool handled;
  final DateTime createdAt;

  factory AdminReviewTask.fromJson(Map<String, dynamic> j) => AdminReviewTask(
        id: '${j['id']}',
        reviewId: '${j['review_id']}',
        placeId: '${j['place_id']}',
        reason: '${j['reason'] ?? ''}',
        handled: j['handled'] == true,
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );
}
