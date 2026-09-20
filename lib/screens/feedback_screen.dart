import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override State<FeedbackScreen> createState()=>_FeedbackScreenState();
}
class _FeedbackScreenState extends State<FeedbackScreen>{
  final db=Supabase.instance.client; List<Map<String,dynamic>> rows=[]; bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{try{final d=await db.from('app_feedback').select().order('created_at',ascending:false);if(mounted)setState((){rows=List<Map<String,dynamic>>.from(d);loading=false;});}catch(e){if(mounted)setState(()=>loading=false);}}
  Future<void> _add()async{final t=TextEditingController(),b=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('앱 이용 / 의견 제출'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:t,maxLength:100,decoration:const InputDecoration(labelText:'제목')),TextField(controller:b,maxLength:2000,maxLines:6,decoration:const InputDecoration(labelText:'내용',border:OutlineInputBorder()))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('보내기'))]));if(ok!=true||t.text.trim().isEmpty||b.text.trim().isEmpty)return;await db.from('app_feedback').insert({'author_id':db.auth.currentUser!.id,'title':t.text.trim(),'body':b.text.trim()});await _load();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('앱 이용 / 의견')),floatingActionButton:FloatingActionButton.extended(onPressed:_add,icon:const Icon(Icons.edit),label:const Text('의견 제출')),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:rows.isEmpty?ListView(children:const [SizedBox(height:180),Center(child:Text('제출한 의견이 없습니다.'))]):ListView.builder(padding:const EdgeInsets.only(bottom:90),itemCount:rows.length,itemBuilder:(_,i){final x=rows[i],answered=x['status']=='answered';return Card(margin:const EdgeInsets.fromLTRB(12,6,12,6),child:ExpansionTile(title:Text('${x['title']}'),subtitle:Text(answered?'답변완료':'답변대기',style:TextStyle(fontWeight:FontWeight.bold,color:answered?Colors.green:null)),children:[ListTile(title:const Text('내 의견'),subtitle:Text('${x['body']}')),if(answered)ListTile(leading:const Icon(Icons.support_agent),title:const Text('관리자 답변'),subtitle:Text('${x['admin_reply']}'))]));})));
}
