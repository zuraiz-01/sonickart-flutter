import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const liveTrackingBikeMarkerSize = Size(78, 42);
const liveTrackingBikeMarkerAnchor = Offset(0.5, 0.5);

const _lightBikeMarkerAsset =
    'assets/images/live_tracking_bike_light_marker.png';
const _darkBikeMarkerAsset = 'assets/images/live_tracking_bike_dark_marker.png';

Future<BitmapDescriptor> loadLiveTrackingBikeMarkerIcon({bool dark = false}) {
  return BitmapDescriptor.asset(
    const ImageConfiguration(size: liveTrackingBikeMarkerSize),
    dark ? _darkBikeMarkerAsset : _lightBikeMarkerAsset,
    width: liveTrackingBikeMarkerSize.width,
    height: liveTrackingBikeMarkerSize.height,
  );
}
