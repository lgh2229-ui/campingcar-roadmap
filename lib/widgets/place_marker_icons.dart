import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Only nine kinds of actual campervan services are shown on the map.
/// Tourism and recreation never add an individual icon.
class PlaceMarkerIcons {
  static const List<String> mapServices = <String>[
    '급수', '블랙탱크 비움', '노지/차박', '공중화장실',
    '매매', '수리', '제작', '부품·용품', '전기차 충전기',
  ];

  static const Map<String,String> symbols = <String,String>{
    '급수':'💧', '청수':'💧',
    '블랙탱크 비움':'🚽', '오수':'🚽',
    '노지/차박':'🅿️', '공중화장실':'🚻',
    '매매':'🚐', '수리':'🔧', 'A/S':'🔧',
    '정비':'🔧', '제작':'🛠️', '부품·용품':'⚙️',
    '전기차 충전기':'🔌',
  };

  static List<String> fromServices(Iterable<String> services) {
    final tags = services.toSet();
    final icons = <String>[];
    if (tags.contains('급수') || tags.contains('청수')) icons.add('💧');
    if (tags.contains('블랙탱크 비움') || tags.contains('오수')) icons.add('🚽');
    if (tags.contains('노지/차박')) icons.add('🅿️');
    if (tags.contains('공중화장실')) icons.add('🚻');
    if (tags.contains('매매')) icons.add('🚐');
    if (tags.contains('수리') || tags.contains('A/S') || tags.contains('정비')) icons.add('🔧');
    if (tags.contains('제작')) icons.add('🛠️');
    if (tags.contains('부품·용품')) icons.add('⚙️');
    if (tags.contains('전기차 충전기')) icons.add('🔌');
    // Still show a neutral location marker for locations offering only
    // leisure, tourism or other unsupported service categories.
    return icons.isEmpty ? const ['📍'] : icons;
  }

  // 1 = single, 2-4 = 2x2, 5-9 = 3 columns with growing rows.
  static int columns(int count) => count <= 1 ? 1 : count <= 4 ? 2 : 3;
  static int rows(int count) => (math.max(1,count) / columns(count)).ceil();
  static double markerWidth(int count) => math.max(52, columns(count)*25+10).toDouble();
  static double markerHeight(int count) => math.max(52, rows(count)*25+10).toDouble();

  static Widget tile(List<String> icons, {int groupCount=1, Color? background}) {
    final visible = icons.take(9).toList(growable:false);
    final width=markerWidth(visible.length);
    final height=markerHeight(visible.length);
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
          children:visible.map((icon)=>SizedBox(
            width:24,height:24,
            child:Center(child:Text(icon,maxLines:1,
              style:const TextStyle(fontSize:17,height:1,decoration:TextDecoration.none),
              textAlign:TextAlign.center)),
          )).toList(growable:false),
        )),
      ),
      if(groupCount>1)Positioned(right:0,top:0,child:Container(
        padding:const EdgeInsets.symmetric(horizontal:3,vertical:1),
        decoration:BoxDecoration(color:const Color(0xff2962a3),borderRadius:BorderRadius.circular(7)),
        child:Text('$groupCount',style:const TextStyle(
          color:Colors.white,fontSize:11,fontWeight:FontWeight.bold)),
      )),
    ]));
  }
}
