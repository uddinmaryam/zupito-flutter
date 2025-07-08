// lib/models/station.dart

import 'package:latlong2/latlong.dart';
import 'package:zupito/models/bike.dart';

class Station {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<Bike> bikes;
  final String description;
  final int capacity;

  Station({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.bikes,
    this.description = '',
    required this.capacity,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      // Ensure 'location.coordinates' are handled if your backend sends them nested
      // Based on your previous code, 'lat' and 'lng' might be directly at top level or nested.
      // Adjust this according to your actual backend response structure.
      // Assuming direct 'latitude' and 'longitude' based on your toJson:
      lat:
          (json['latitude'] as num?)?.toDouble() ??
          0.0, // Added null check and default
      lng:
          (json['longitude'] as num?)?.toDouble() ??
          0.0, // Added null check and default
      bikes:
          (json['bikes'] as List<dynamic>?)
              ?.map((bikeJson) => Bike.fromJson(bikeJson))
              .toList() ??
          [],
      description: json['description'] ?? '',
      capacity: json['capacity'] ?? 10,
    );
  }

  int get availableBikes {
    return bikes.where((bike) => bike.isAvailable).length;
  }

  int get unavailableBikes {
    return bikes.where((bike) => !bike.isAvailable).length;
  }

  // Changed `get location => null;` to the correct LatLng getter
  LatLng get location => LatLng(lat, lng);

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'bikes': bikes.map((bike) => bike.toJson()).toList(),
      'description': description,
      'capacity': capacity,
    };
  }

  // ADD THESE TWO METHODS TO YOUR STATION CLASS
  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true; // If they are the exact same instance, they are equal
    return other is Station && // Check if 'other' is also a Station object
        other.id == id; // And compare by their unique 'id'
  }

  @override
  int get hashCode => id.hashCode; // Generate a hash code based on the unique 'id'
}
