import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralised marker icons. All saved service tags are represented on the
/// map, without a take(n) limit. Nearby activity tags remain identifiable.
class PlaceMarkerIcons {
  // Only four campervan services appear on the MAP marker.
  // Tourism, recreation, repair, sales and other place data are still visible
  // in the place details and filters, but never create category marker icons.
  static const Map<String,String> symbols = <String,String>{
    '급수':'💧',
    '청수':'💧',
    '블랙탱크 비움':'🚽',
    '오수':'🚽',
    '노지/차박':'🅿️',
    '공중화장실':'🚻',
  };

  static List<String> fromServices(Iterable<String> services) {
    final tags=services.toSet();
    final result=<String>[];
    if (tags.contains('급수') || tags.contains('청수')) result.add('💧');
    if (tags.contains('블랙탱크 비움') || tags.contains('오수')) result.add('🚽');
    if (tags.contains('노지/차박')) result.add('🅿️');
    if (tags.contains('공중화장실')) result.add('🚻');
    // A neutral location pin preserves navigation to places offering only
    // non-core services, without representing tourism or leisure as a marker.
    return result.isEmpty ? <String>['📍'] : result;
  }

  // All qualifying map icons fit in a compact 2x2 grid.
  static int columns(int count) => count <= 1 ? 1 : 2;
  static int rows(int count) => (math.max(1,count) / columns(count)).ceil();
  static double markerWidth(int count) => math.max(52,columns(count)*25+10).toDouble();
  static double markerHeight(int count) => math.max(52,rows(count)*25+10).toDouble();

  static Widget tile(List<String> icons,{int groupCount=1,Color? background}) {
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
