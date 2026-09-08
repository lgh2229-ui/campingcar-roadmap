class ReviewComment {
  ReviewComment({
    required this.id,
    required this.reviewId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String reviewId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory ReviewComment.fromJson(Map<String, dynamic> j) => ReviewComment(
        id: '${j['id']}',
        reviewId: '${j['review_id']}',
        authorId: '${j['author_id']}',
        authorName: '${j['author_name'] ?? ''}',
        body: '${j['body'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );
}
