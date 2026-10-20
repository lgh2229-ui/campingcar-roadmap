import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralised marker icons. All saved service tags are represented on the
/// map, without a take(n) limit. Nearby activity tags remain identifiable.
class PlaceMarkerIcons {
  static const Map<String,String> symbols = <String,String>{
    '급수':'💧',
    '청수':'💧',
    '블랙탱크 비움':'🚽',
    '노지/차박':'🅿️',
    '공중화장실':'🚻',
    '전기':'🔌',
    '캠핑장':'🏕️',
    '제작':'🛠️',
    '매매':'🚐',
    'A/S':'🔧',
    '부품·용품':'⚙️',
    '수리':'🔧',
    '정비':'🔩',
    '장착':'🛠️',
    '상담':'📞',
    '관광지':'🏞️',
    '산책':'🚶',
    '등산':'🥾',
    '낚시':'🎣',
    '해루질':'🐚',
    '수상레포츠':'🏄',
    '지상레포츠':'🚴',
    '카지노':'🎰',
    '자전거':'🚲',
    '수영':'🏊',
    '서핑':'🏄',
    '카약·SUP':'🛶',
    '스노클링':'🤿',
    '스키·눈썰매':'⛷️',
    '골프':'⛳',
    '온천·스파':'♨️',
    '문화체험':'🎨',
    '시장·쇼핑':'🛍️',
  };

  static List<String> fromServices(Iterable<String> services) {
    final result = <String>[];
    final seen = <String>{};
    for (final service in services) {
      final icon = symbols[service] ?? '📌';
      // Multiple distinct service tags share icons, but every service can
      // still be inspected by tapping the marker. Deduplicate identical tags.
      if (seen.add(service)) result.add(icon);
    }
    return result.isEmpty ? <String>['📍'] : result;
  }

  // Four icons are displayed 2x2. For more than four, use three columns
  // and as many rows as necessary instead of silently hiding services.
  static int columns(int count) => count <= 4 ? 2 : 3;
  static int rows(int count) => (math.max(1,count) / columns(count)).ceil();
  static double markerWidth(int count) => math.max(52,columns(count)*25+10).toDouble();
  static double markerHeight(int count) => math.max(52,rows(count)*25+10).toDouble();

  static Widget tile(List<String> icons,{int groupCount=1,Color? background}) {
    final cols=columns(icons.length);
    final width=markerWidth(icons.length);
    final height=markerHeight(icons.length);
    return SizedBox(width:width,height:height,child:Stack(clipBehavior:Clip.none,children:[
      Container(
        width:width,height:height,
        padding:const EdgeInsets.all(3),
        decoration:BoxDecoration(
          color:background??Colors.white,
          border:Border.all(color:Colors.black87,width:2),
          borderRadius:BorderRadius.circular(8),
          boxShadow:const [BoxShadow(color:Colors.black26,blurRadius:3,offset:Offset(0,1))],
        ),
        child:Center(child:Wrap(
          spacing:1,runSpacing:1,
          children:icons.map((i)=>SizedBox(
            width:24,height:24,
            child:Center(child:Text(i,maxLines:1,
              style:const TextStyle(fontSize:17,height:1,decoration:TextDecoration.none),
              textAlign:TextAlign.center)),
          )).toList(growable:false),
        )),
      ),
      if(groupCount>1)Positioned(right:0,top:0,child:Container(
        padding:const EdgeInsets.symmetric(horizontal:3,vertical:1),
        decoration:BoxDecoration(color:const Color(0xff2962a3),borderRadius:BorderRadius.circular(7)),
        child:Text('$groupCount',style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold)),
      )),
    ]));
  }
}
