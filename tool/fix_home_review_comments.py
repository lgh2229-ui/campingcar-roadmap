from pathlib import Path

p = Path("lib/screens/home_screen.dart")
s = p.read_text()
start = s.index("  Future<void> _openReviewComments(PlaceReview review) async {")
end = s.index("  Future<void> _openReview(Place p) async {", start)

method = """  Future<void> _openReviewComments(PlaceReview review) async {
    List<ReviewComment> comments = [];
    try {
      comments = await widget.data.reviewComments(review.id);
    } catch (e) {
      _msg('댓글을 불러오지 못했습니다: $e');
      return;
    }
    if (!mounted) return;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('리뷰 댓글'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              children: [
                Expanded(
                  child: comments.isEmpty
                      ? const Center(child: Text('아직 댓글이 없습니다.'))
                      : ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (_, i) {
                            final x = comments[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.reply),
                              title: Text(x.authorName),
                              subtitle: Text(x.body),
                            );
                          },
                        ),
                ),
                TextField(
                  controller: controller,
                  maxLength: 300,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '댓글 입력',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () async {
                final body = controller.text.trim();
                if (body.isEmpty) return;
                try {
                  await widget.data.addReviewComment(
                    reviewId: review.id,
                    body: body,
                  );
                  controller.clear();
                  comments = await widget.data.reviewComments(review.id);
                  setDialogState(() {});
                } catch (e) {
                  _msg('댓글 등록에 실패했습니다: $e');
                }
              },
              child: const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }

"""

p.write_text(s[:start] + method + s[end:])
