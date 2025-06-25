import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/station.dart';

class StationMarker extends StatelessWidget {
  final Station station;
  final VoidCallback onTap;

  const StationMarker({
    super.key,
    required this.station,
    required this.onTap,
  });

  Marker get marker => Marker(
        point: LatLng(station.lat, station.lng),
        width: 60,
        height: 60,
        child: IconButton(
          icon: const Icon(Icons.location_on, color: Colors.black, size: 35),
          onPressed: onTap,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink(); // placeholder; real usage is via `.marker`
  }
}
