import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Permanent admin notification history. Reading never deletes an event.
class AdminNotificationLogScreen extends StatefulWidget {
  const AdminNotificationLogScreen({super.key});
  @override State<AdminNotificationLogScreen> createState() => _AdminNotificationLogScreenState();
}

class _AdminNotificationLogScreenState extends State<AdminNotificationLogScreen> {
  final db = Supabase.instance.client;
  List<Map<String, dynamic>> rows = [];
  bool busy = true;
  String? error;
  Future<void> load() async {
    try {
      final data = await db.from('notifications').select()
        .eq('user_id', db.auth.currentUser!.id)
        .order('created_at', ascending: false).limit(500);
      if (mounted) setState(() { rows = List<Map<String,dynamic>>.from(data); busy = false; error = null; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; busy = false; });
    }
  }
  @override void initState() { super.initState(); load(); }
  String date(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    return d == null ? '' : d.toString().substring(0,16);
  }
  Future<Map<String,dynamic>?> one(String table, String id) async {
    final data = await db.from(table).select().eq('id', id).maybeSingle();
    return data == null ? null : Map<String,dynamic>.from(data);
  }
  Future<void> openItem(Map<String,dynamic> n) async {
    try {
      if (n['is_read'] != true) {
        await db.from('notifications').update({'is_read': true}).eq('id', n['id']);
        if (mounted) setState(() => n['is_read'] = true);
      }
      final kind = '${n['kind'] ?? ''}', id = '${n['reference_id'] ?? ''}';
      String title = '${n['title'] ?? '알림'}';
      final lines = <String>[];
      final photos = <String>[];
      Future<void> reviewDetail(Map<String,dynamic>? review) async {
        if (review == null) return;
        lines.add('작성자: ${review['author_name'] ?? review['author_id'] ?? ''}');
        lines.add('내용: ${review['body'] ?? ''}');
        lines.add('상태: ${review['status'] ?? ''}');
        final p = review['place_id'];
        if (p != null) {
          final place = await one('places', '$p');
          if (place != null) lines.insert(0, '장소: ${place['name']}\n주소: ${place['address']}');
        }
        photos.addAll(List<String>.from(review['photo_urls'] ?? const []));
      }
      if (kind == 'new_member') {
        final m = await one('profiles', id);
        if (m != null) {
          title = '신규 회원 · ${m['nickname'] ?? m['username'] ?? ''}';
          lines.addAll(['아이디: ${m['username'] ?? ''}', '닉네임: ${m['nickname'] ?? ''}',
            '연락처: ${m['phone'] ?? ''}', '가입일: ${date(m['created_at'])}',
            '차량: ${m['vehicle_name'] ?? ''}']);
        }
      } else if (kind == 'new_review' || kind == 'review_admin_task') {
        await reviewDetail(await one('reviews', id));
      } else if (kind == 'new_comment') {
        final c = await one('review_comments', id);
        if (c != null) {
          lines.add('댓글 작성자: ${c['author_name'] ?? c['author_id'] ?? ''}');
          lines.add('댓글: ${c['body'] ?? ''}');
          lines.add('작성일: ${date(c['created_at'])}');
          lines.add('──── 원문 리뷰 ────');
          await reviewDetail(await one('reviews', '${c['review_id']}'));
        }
      } else if (kind == 'new_activity_review') {
        final a = await one('activity_spot_reviews', id);
        if (a != null) {
          lines.addAll(['장소: ${a['spot_name'] ?? ''}', '활동: ${a['activity'] ?? ''}',
            '작성자: ${a['author_name'] ?? ''}', '내용: ${a['body'] ?? ''}']);
          photos.addAll(List<String>.from(a['photo_urls'] ?? const []));
        }
      } else if (kind == 'new_market_post') {
        final m = await one('vehicle_market_listings', id);
        if (m != null) {
          title = '${m['title'] ?? '중고차 판매 글'}';
          lines.addAll(['차량: ${m['manufacturer'] ?? ''} ${m['model'] ?? ''}',
            '가격: ${m['price_krw'] ?? '-'}원', '지역: ${m['region'] ?? ''}',
            '설명: ${m['description'] ?? ''}', '연락처: ${m['phone'] ?? ''}']);
          photos.addAll(List<String>.from(m['image_urls'] ?? const []));
        }
      } else if (kind == 'feedback') {
        final f = await one('app_feedback', id);
        if (f != null) { title = '${f['title'] ?? title}'; lines.add('${f['body'] ?? ''}'); photos.addAll(List<String>.from(f['photo_urls'] ?? const [])); }
      } else if (kind == 'place_request' || kind == 'place_result') {
        final p = await one('places', id);
        if (p != null) lines.addAll(['장소: ${p['name'] ?? ''}', '주소: ${p['address'] ?? ''}',
          '시설: ${p['services'] ?? ''}', '이용안내: ${p['note'] ?? ''}']);
      } else if (kind == 'new_activity_report') {
        final a = await one('place_activity_reports', id);
        if (a != null) lines.addAll(['활동: ${a['activity'] ?? ''}', '신고내용: ${a['reason'] ?? ''}']);
      } else if (kind == 'vehicle_report') {
        final a = await one('vehicle_market_reports', id);
        if (a != null) lines.add('신고내용: ${a['reason'] ?? ''}');
      } else if (kind == 'place_report') {
        final a = await one('place_reports', id);
        if (a != null) lines.add('신고내용: ${a['reason'] ?? ''}');
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        showDragHandle: true, useSafeArea: true, builder: (sheet) => DraggableScrollableSheet(
          expand: false, initialChildSize: .7, minChildSize: .35, maxChildSize: .95,
          builder: (_, scroll) => ListView(controller: scroll,
            padding: const EdgeInsets.fromLTRB(20,8,20,30), children: [
              Text(title, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height:8), Text(date(n['created_at'])),
              const Divider(height:26),
              if (lines.isEmpty) Text('${n['body'] ?? ''}\n\n원본 게시물이 삭제되었거나 확인할 수 없습니다.')
              else ...lines.map((s) => Padding(padding: const EdgeInsets.only(bottom:12), child: Text(s))),
              ...photos.map((p) => Padding(padding: const EdgeInsets.only(bottom:8),
                child: Image.network(p, height:180, fit:BoxFit.contain,
                  errorBuilder: (_,__,___) => const Text('이미지를 불러오지 못했습니다.')))),
            ])));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('상세 내용 조회 실패: $e')));
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('알림 로그'), actions: [
      IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip:'새로고침')]),
    body: busy ? const Center(child:CircularProgressIndicator()) :
      error != null ? Center(child:Text('알림 조회 실패: $error')) :
      RefreshIndicator(onRefresh: load, child: rows.isEmpty ?
        ListView(children: const [SizedBox(height:150),Center(child:Text('알림 내역이 없습니다.'))]) :
        ListView.separated(itemCount:rows.length,
          separatorBuilder:(_,__) => const Divider(height:1),
          itemBuilder:(_,i) {
            final n=rows[i];
            return ListTile(
              leading: Icon(n['is_read']==true?Icons.notifications_none:Icons.notifications_active,
                color:n['is_read']==true?null:Theme.of(context).colorScheme.primary),
              title: Text('${n['title'] ?? ''}', style:TextStyle(
                fontWeight:n['is_read']==true?FontWeight.normal:FontWeight.bold)),
              subtitle: Text('${n['body'] ?? ''}\n${date(n['created_at'])}', maxLines:3,
                overflow:TextOverflow.ellipsis),
              trailing:const Icon(Icons.chevron_right), isThreeLine:true,
              onTap:()=>openItem(n));
          })));
}
