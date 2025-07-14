import 'package:flutter/material.dart'; // This import might not be strictly necessary for a model, but kept for context

class Bike {
  final String? code;
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double pricePerMinute;
  bool isAvailable;

  final int? availableInMinutes;
  bool isUnlocked;

  // Added missing fields based on compilation errors
  final String? assignedStation; // Station ID the bike is currently assigned to
  final String? status; // e.g., 'available', 'in_use', 'maintenance'

  Bike({
    this.code,
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.pricePerMinute,
    required this.isAvailable,
    this.availableInMinutes,
    this.isUnlocked = false,
    this.assignedStation, // Initialize the new field
    this.status, // Initialize the new field
  });

  factory Bike.fromJson(Map<String, dynamic> json) {
    // Safely parse location. If 'location' is null or not a Map,
    // default lat/lng to 0.0.
    final Map<String, dynamic>? locationJson =
        json['location'] as Map<String, dynamic>?;

    return Bike(
      code: json['code'] as String? ?? '',
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? (json['code'] as String? ?? ''),
      lat: (locationJson?['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (locationJson?['lng'] as num?)?.toDouble() ?? 0.0,
      pricePerMinute: (json['pricePerMinute'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] as bool? ?? false,
      availableInMinutes: json['availableInMinutes'] as int?,
      isUnlocked: false, // set from UI, not from API
      // Parse the newly added fields defensively
      assignedStation: json['assignedStation'] as String?, // Can be null
      status: json['status'] as String?, // Can be null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      '_id': id,
      'name': name,
      'location': {'lat': lat, 'lng': lng},
      'pricePerMinute': pricePerMinute,
      'isAvailable': isAvailable,
      'availableInMinutes': availableInMinutes,
      'isUnlocked': isUnlocked,
      'assignedStation': assignedStation, // Include in toJson
      'status': status, // Include in toJson
    };
  }

  Bike copyWith({
    bool? isUnlocked,
    String? assignedStation, // Add to copyWith
    String? status, // Add to copyWith
  }) {
    return Bike(
      code: code,
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      pricePerMinute: pricePerMinute,
      isAvailable: isAvailable,
      availableInMinutes: availableInMinutes,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      assignedStation:
          assignedStation ?? this.assignedStation, // Copy new field
      status: status ?? this.status, // Copy new field
    );
  }
}
