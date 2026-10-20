import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/place.dart';

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
    this.currentLocation,
    this.selectedSpot,
    this.locationPickMode = false,
  });

  final List<List<Place>> groups;
  final ll.LatLng center;
  final double initialZoom;
  final ll.LatLng? currentLocation;
  final ll.LatLng? selectedSpot;
  final bool locationPickMode;
  final void Function(List<Place>) onGroupTap;
  final VoidCallback onMapTap;
  final ValueChanged<ll.LatLng> onLongPress;
  final ValueChanged<ll.LatLng> onGestureCenter;

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

  String _iconText(Place place) {
    final values = <String>[];
    if (place.services.contains('급수')) values.add('💧');
    if (place.services.contains('블랙탱크 비움')) values.add('🚽');
    if (place.services.contains('노지/차박')) values.add('🅿️');
    if (place.services.contains('공중화장실')) values.add('🚻');
    if (place.services.contains('매매')) values.add('🚐');
    if (place.services.contains('수리')) values.add('🔧');
    if (place.services.contains('캠핑장')) values.add('🏕️');
    return values.isEmpty ? '📍' : values.take(3).join();
  }

  Future<NOverlayImage> _iconFor(String key, {bool selected = false}) async {
    final cached = _imageCache[key];
    if (cached != null) return cached;
    final image = await NOverlayImage.fromWidget(
      context: context,
      size: selected ? const Size(70, 80) : const Size(48, 48),
      widget: selected
          ? const Center(child: Icon(Icons.location_pin, color: Colors.red, size: 58))
          : Center(
              child: Container(
                width: 45,
                height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black87, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(
                    color: Colors.black26, blurRadius: 3, offset: Offset(0, 1),
                  )],
                ),
                child: Text(key,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 16, decoration: TextDecoration.none),
                  textAlign: TextAlign.center),
              ),
            ),
    );
    _imageCache[key] = image;
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
        final iconKey = group.length > 1
            ? '📍${group.length}'
            : _iconText(first);
        final icon = await _iconFor(iconKey);
        final marker = NMarker(
          id: 'place_${first.id}',
          position: NLatLng(first.latitude, first.longitude),
          size: const Size(48, 48),
          icon: icon,
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
          icon: await _iconFor('selected', selected: true),
          caption: NOverlayCaption(
            text: widget.locationPickMode ? '수정 위치' : '등록 위치',
          ),
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
        if (controller != null &&
            widget.locationPickMode && _cameraMovedByGesture) {
          final point = _flutter(controller.nowCameraPosition.target);
          widget.onGestureCenter(point);
        }
        _cameraMovedByGesture = false;
      },
    );
  }
}
