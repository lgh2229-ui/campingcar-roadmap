class PlaceReview {
  PlaceReview({
    required this.id,
    required this.placeId,
    required this.authorId,
    required this.authorName,
    required this.status,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String placeId;
  final String authorId;
  final String authorName;
  final String status;
  final String body;
  final DateTime createdAt;

  factory PlaceReview.fromJson(Map<String, dynamic> j) => PlaceReview(
        id: '${j['id']}',
        placeId: '${j['place_id']}',
        authorId: '${j['author_id']}',
        authorName: '${j['author_name'] ?? ''}',
        status: '${j['status'] ?? 'ok'}',
        body: '${j['body'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      );
}
