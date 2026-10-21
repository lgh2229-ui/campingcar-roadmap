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
    '블랙탱크 비움':'DUMP', '오수':'DUMP',
    '노지/차박':'🅿️', '공중화장실':'🚻',
    '매매':'🚐', '수리':'🔧', 'A/S':'🔧',
    '정비':'🔧', '제작':'🛠️', '부품·용품':'⚙️',
    '전기차 충전기':'EV',
  };

  static List<String> fromServices(Iterable<String> services) {
    final tags = services.toSet();
    final icons = <String>[];
    if (tags.contains('급수') || tags.contains('청수')) icons.add('💧');
    if (tags.contains('블랙탱크 비움') || tags.contains('오수')) icons.add('DUMP');
    if (tags.contains('노지/차박') || tags.contains('캠핑장')) icons.add('🅿️');
    if (tags.contains('공중화장실')) icons.add('🚻');
    if (tags.contains('매매')) icons.add('🚐');
    if (tags.contains('수리') || tags.contains('A/S') || tags.contains('정비')) icons.add('🔧');
    if (tags.contains('제작')) icons.add('🛠️');
    if (tags.contains('부품·용품')) icons.add('⚙️');
    // An EV charger is an amenity of a registered camper overnight place.
    // Standalone charging stations must not get a camping-roadmap EV pin.
    if (tags.contains('노지/차박') && tags.contains('전기차 충전기')) {
      icons.add('EV');
    }
    // Still show a neutral location marker for locations offering only
    // leisure, tourism or other unsupported service categories.
    return icons.isEmpty ? const ['📍'] : icons;
  }

  // 1 = single, 2-4 = 2x2, 5-9 = 3 columns with growing rows.
  static int columns(int count) => count <= 1 ? 1 : count <= 4 ? 2 : 3;
  static int rows(int count) => (math.max(1,count) / columns(count)).ceil();
  static double markerWidth(int count) => math.max(52, columns(count)*25+10).toDouble();
  static double markerHeight(int count) => math.max(52, rows(count)*25+10).toDouble();

  /// Simple vector drawings remain sharp even when captured by Naver Maps.
  static Widget servicePictogram(String service, {double size=24}) {
    if (service=='블랙탱크 비움' || service=='오수') {
      return SizedBox(width:size,height:size,
        child:CustomPaint(painter:const _DumpStationPainter()));
    }
    if (service=='전기차 충전기') {
      return SizedBox(width:size,height:size,
        child:CustomPaint(painter:const _EvChargingPainter()));
    }
    return Icon(symbols[service]=='💧' ? Icons.water_drop_outlined :
        Icons.place_outlined,size:size);
  }

  static Widget _symbolWidget(String symbol) {
    if(symbol=='DUMP')return servicePictogram('블랙탱크 비움');
    if(symbol=='EV')return servicePictogram('전기차 충전기');
    return Text(symbol,maxLines:1,
      style:const TextStyle(fontSize:17,height:1,decoration:TextDecoration.none),
      textAlign:TextAlign.center);
  }

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
            child:Center(child:_symbolWidget(icon)),
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


/// Inlet + waste hose + downward discharge arrow + drainage grate.
/// Unlike a toilet emoji, this specifically means black-tank dumping.
class _DumpStationPainter extends CustomPainter {
  const _DumpStationPainter();
  @override void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width/24,size.height/24);
    final ink=Paint()..color=const Color(0xff17466b)
      ..style=PaintingStyle.stroke..strokeWidth=2.15
      ..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    final accent=Paint()..color=const Color(0xff087d8f)
      ..style=PaintingStyle.stroke..strokeWidth=2.15
      ..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    // A sewage outlet / hose curving down into the dump inlet.
    canvas.drawPath(Path()..moveTo(3,4)..lineTo(8,4)
      ..lineTo(8,9)..quadraticBezierTo(8,12,12,12)
      ..lineTo(15,12)..lineTo(15,16),ink);
    // Outlet coupling, recognizable on a tiny map marker.
    canvas.drawLine(const Offset(2,2),const Offset(2,6),ink);
    canvas.drawLine(const Offset(4,2),const Offset(4,6),ink);
    // Arrow shows wastewater discharged downward, not drinking water.
    canvas.drawPath(Path()..moveTo(12.5,14.5)
      ..lineTo(15,17)..lineTo(17.5,14.5),accent);
    // Ground-level disposal grate.
    canvas.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(9,19,13,3),const Radius.circular(1)),ink);
    for(final x in <double>[12,15,18]){
      canvas.drawLine(Offset(x,19),Offset(x,22),ink);
    }
    canvas.restore();
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

/// Car + separate charging pedestal + electrical bolt. This avoids a generic
/// power plug which could be confused with camper shore-power supply.
class _EvChargingPainter extends CustomPainter {
  const _EvChargingPainter();
  @override void paint(Canvas canvas,Size size){
    canvas.save();canvas.scale(size.width/24,size.height/24);
    final ink=Paint()..color=const Color(0xff145d90)
      ..style=PaintingStyle.stroke..strokeWidth=1.9
      ..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    final spark=Paint()..color=const Color(0xff138c78)
      ..style=PaintingStyle.stroke..strokeWidth=1.8
      ..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    // Vehicle silhouette, windshield and visible wheels.
    canvas.drawPath(Path()..moveTo(2,15)..lineTo(4,10)
      ..lineTo(11,10)..lineTo(14,15)..lineTo(14,19)
      ..lineTo(2,19)..close(),ink);
    canvas.drawLine(const Offset(4.5,15),const Offset(12,15),ink);
    canvas.drawCircle(const Offset(5,20),1.15,ink);
    canvas.drawCircle(const Offset(11,20),1.15,ink);
    // Vertical charging post and its screen.
    canvas.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(16,3,6,17),const Radius.circular(1.25)),ink);
    canvas.drawLine(const Offset(17.4,5.8),const Offset(20.5,5.8),ink);
    canvas.drawPath(Path()..moveTo(20,10)..lineTo(18,13)
      ..lineTo(20.5,13)..lineTo(18.5,16),spark);
    // Connector runs from charging post toward the vehicle.
    canvas.drawPath(Path()..moveTo(16,16)..quadraticBezierTo(15.5,16,14,17),ink);
    canvas.restore();
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
