import 'package:flutter/material.dart';
import 'package:zupito/models/bike.dart'; // Import the Bike model

class Station {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int capacity;
  final List<Bike> bikes; // FIX: Changed to List<Bike>

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.bikes,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      capacity: json['capacity'] as int? ?? 0,
      // FIX: Map each item in the 'bikes' list to a Bike.fromJson
      bikes:
          (json['bikes'] as List<dynamic>?)
              ?.map((e) => Bike.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Getters for available/unavailable bikes will now work correctly
  int get availableBikes {
    return bikes.where((bike) => bike.isAvailable).length;
  }

  int get unavailableBikes {
    return bikes.where((bike) => !bike.isAvailable).length;
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      // When converting back to JSON, convert Bike objects to their JSON representation
      'bikes': bikes.map((bike) => bike.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Station && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
