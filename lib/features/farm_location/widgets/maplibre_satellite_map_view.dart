import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/constants/app_constants.dart';

/// MapLibre native satellite view with MapTiler Cloud Hybrid style.
class MapLibreSatelliteMapView extends StatelessWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final void Function(MapLibreMapController controller)? onMapCreated;
  final void Function(CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;

  const MapLibreSatelliteMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 15.0,
    this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
  });

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: AppConstants.mapTilerStyleUrl,
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: initialZoom,
      ),
      onMapCreated: onMapCreated,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      trackCameraPosition: true,
      myLocationEnabled: false,
      attributionButtonMargins: const Point(-500, -500),
      compassEnabled: false,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: false,
      // Each factory MUST use the concrete recognizer type — not OneSequenceGestureRecognizer
      // Using the same type for multiple factories causes a Flutter assertion error.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      },
    );
  }
}
