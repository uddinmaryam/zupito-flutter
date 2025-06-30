import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/station.dart';

class StationMarker {
  static Marker build({required Station station, required VoidCallback onTap}) {
    return Marker(
      point: LatLng(station.lat, station.lng),
      width: 60,
      height: 60,
      child: IconButton(
        icon: const Icon(Icons.location_on, color: Colors.black, size: 40),
        onPressed: onTap,
      ),
    );
  }
}
