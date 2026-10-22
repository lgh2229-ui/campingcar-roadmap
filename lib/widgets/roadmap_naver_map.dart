import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/place.dart';
import 'place_marker_icons.dart';

/// Native Naver basemap with the Roadmap's original group markers and
/// place-selection gestures. No locations are copied into Naver's databases.
class RoadmapNaverMap extends StatefulWidget {
  const RoadmapNaverMap({
    super.key,
    required this.groups,
    required this.center,
    this.initialZoom = 14,
    required this.onGroupTap,
    required this.onMapTap,
    required this.onLongPress,
    required this.onGestureCenter,
    required this.onCameraSettled,
    this.currentLocation,
    this.selectedSpot,
    this.activitySpot,
    this.activitySpotName,
    this.locationPickMode = false,
  });

  final List<List<Place>> groups;
  final ll.LatLng center;
  final double initialZoom;
  final ll.LatLng? currentLocation;
  final ll.LatLng? selectedSpot;
  final ll.LatLng? activitySpot;
  final String? activitySpotName;
  final bool locationPickMode;
  final void Function(List<Place>) onGroupTap;
  final VoidCallback onMapTap;
  final ValueChanged<ll.LatLng> onLongPress;
  final ValueChanged<ll.LatLng> onGestureCenter;
  final void Function(ll.LatLng center, double zoom, bool byGesture) onCameraSettled;

  @override
  State<RoadmapNaverMap> createState() => RoadmapNaverMapState();
}

class RoadmapNaverMapState extends State<RoadmapNaverMap> {
  NaverMapController? _controller;
  final Map<String, NOverlayImage> _imageCache = {};
  bool _cameraMovedByGesture = false;
  int _overlayGeneration = 0;

  NLatLng _native(ll.LatLng p) => NLatLng(p.latitude, p.longitude);
  ll.LatLng _flutter(NLatLng p) => ll.LatLng(p.latitude, p.longitude);

  void moveTo(ll.LatLng target, double zoom) {
    final controller = _controller;
    if (controller == null) return;
    controller.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: _native(target), zoom: zoom),
    );
  }

  @override
  void didUpdateWidget(covariant RoadmapNaverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups ||
        oldWidget.selectedSpot != widget.selectedSpot ||
        oldWidget.activitySpot != widget.activitySpot ||
        oldWidget.activitySpotName != widget.activitySpotName ||
        oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.locationPickMode != widget.locationPickMode) {
      _scheduleOverlays();
    }
  }

  @override
  void dispose() {
    _overlayGeneration++;
    _controller = null;
    super.dispose();
  }

  void _scheduleOverlays() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller != null) _refreshOverlays();
    });
  }

  Future<NOverlayImage> _iconFor(List<String> icons,{int groupCount=1}) async {
    final key='${icons.join('|')}#$groupCount';
    final cached=_imageCache[key];
    if(cached!=null)return cached;
    final image=await NOverlayImage.fromWidget(
      context:context,
      size:Size(PlaceMarkerIcons.markerWidth(icons.length),
        PlaceMarkerIcons.markerHeight(icons.length)),
      widget:PlaceMarkerIcons.tile(icons,groupCount:groupCount),
    );
    _imageCache[key]=image;
    return image;
  }

  Future<NOverlayImage> _selectedIcon() async {
    final cached=_imageCache['selected'];
    if(cached!=null)return cached;
    final image=await NOverlayImage.fromWidget(
      context:context,
      size:const Size(70,80),
      widget:const Center(child:Icon(Icons.location_pin,color:Colors.red,size:58)),
    );
    _imageCache['selected']=image;
    return image;
  }

  Future<void> _refreshOverlays() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final generation = ++_overlayGeneration;
    try {
      final locationOverlay = controller.getLocationOverlay();
      final gps = widget.currentLocation;
      if (gps != null) {
        locationOverlay.setPosition(_native(gps));
        locationOverlay.setIsVisible(true);
      } else {
        locationOverlay.setIsVisible(false);
      }

      final overlays = <NMarker>[];
      for (final group in widget.groups) {
        if (generation != _overlayGeneration || !mounted) return;
        if (group.isEmpty) continue;
        final first = group.first;
        // Merge all represented services at shared coordinates.
        // Never replace service symbols with a generic group pin.
        final serviceTags=group.expand((p)=>p.services).toSet();
        final icons=PlaceMarkerIcons.fromServices(serviceTags);
        final icon=await _iconFor(icons,groupCount:group.length);
        final marker=NMarker(
          id:'place_${first.id}',
          position:NLatLng(first.latitude,first.longitude),
          size:Size(PlaceMarkerIcons.markerWidth(icons.length),
            PlaceMarkerIcons.markerHeight(icons.length)),
          icon:icon,
        );
        marker.setOnTapListener((_) {
          if (mounted) widget.onGroupTap(group);
        });
        overlays.add(marker);
      }

      final selected = widget.selectedSpot;
      if (selected != null && generation == _overlayGeneration && mounted) {
        overlays.add(NMarker(
          id: 'selected_place',
          position: _native(selected),
          size: const Size(70, 80),
          icon: await _selectedIcon(),
          caption: NOverlayCaption(
            text: widget.locationPickMode ? '수정 위치' : '등록 위치',
          ),
        ));
      }
      final activitySpot = widget.activitySpot;
      if (activitySpot != null && generation == _overlayGeneration && mounted) {
        overlays.add(NMarker(
          id: 'nearby_activity_spot',
          position: _native(activitySpot),
          size: const Size(70, 80),
          icon: await _selectedIcon(),
          caption: NOverlayCaption(text: widget.activitySpotName ?? '주변 장소'),
        ));
      }
      if (generation != _overlayGeneration || !mounted) return;
      await controller.clearOverlays(type: NOverlayType.marker);
      if (generation != _overlayGeneration || !mounted) return;
      await controller.addOverlayAll(overlays.toSet());
    } catch (error) {
      debugPrint('Naver Roadmap marker refresh: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      options: NaverMapViewOptions(
        mapType: NMapType.basic,
        initialCameraPosition: NCameraPosition(
          target: _native(widget.center), zoom: widget.initialZoom,
        ),
        rotationGesturesEnable: false,
        tiltGesturesEnable: false,
        logoMargin: const EdgeInsets.only(left: 8, bottom: 96),
      ),
      onMapReady: (controller) {
        _controller = controller;
        _scheduleOverlays();
        moveTo(widget.center, widget.initialZoom);
      },
      onMapTapped: (_, __) => widget.onMapTap(),
      onMapLongTapped: (_, point) => widget.onLongPress(_flutter(point)),
      onCameraChange: (reason, animated) {
        if (reason == NCameraUpdateReason.gesture) {
          _cameraMovedByGesture = true;
        }
      },
      onCameraIdle: () {
        final controller = _controller;
        if (controller != null) {
          final camera = controller.nowCameraPosition;
          final point = _flutter(camera.target);
          widget.onCameraSettled(point, camera.zoom, _cameraMovedByGesture);
          if (widget.locationPickMode && _cameraMovedByGesture) {
            widget.onGestureCenter(point);
          }
        }
        _cameraMovedByGesture = false;
      },
    );
  }
}
