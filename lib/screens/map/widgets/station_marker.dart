import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// Corrected import path to use 'zupito'
import 'package:zupito/models/station.dart'; // Ensure this imports your correct Station model

class StationMarker {
  static Marker build({required Station station, required VoidCallback onTap}) {
    return Marker(
      // FIX: Use station.latitude and station.longitude
      point: LatLng(station.latitude, station.longitude),
      width: 60,
      height: 60,
      child: IconButton(
        icon: Icon(
          Icons.location_on,
          // You might want to make the color dynamic based on station availability
          // For example:
          color: station.bikes.isNotEmpty
              ? Colors.indigo
              : Colors.grey, // If station.bikes is List<Bike>
          // Or if station.bikes is List<String> (IDs) and you just want to show if it has any bikes:
          // color: station.bikes.isNotEmpty ? Colors.indigo : Colors.grey,
          size: 40,
        ),
        onPressed: onTap,
      ),
    );
  }
}
