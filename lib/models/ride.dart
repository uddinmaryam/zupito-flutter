import 'package:flutter/material.dart'; // Not strictly needed for model, but often included

// Simplified nested models for populated data
class RideUser {
  final String id;
  final String username;
  final String? email; // Assuming email might be populated

  RideUser({required this.id, required this.username, this.email});

  factory RideUser.fromJson(Map<String, dynamic> json) {
    return RideUser(
      id: json['_id'] as String? ?? '',
      username:
          json['username'] as String? ??
          json['name'] as String? ??
          'Unknown User', // Handle 'name' or 'username'
      email: json['email'] as String?,
    );
  }

  // Add toJson method for RideUser
  Map<String, dynamic> toJson() {
    return {'_id': id, 'username': username, 'email': email};
  }
}

class RideBike {
  final String id;
  final String code; // Assuming bike 'code' is populated

  RideBike({required this.id, required this.code});

  factory RideBike.fromJson(Map<String, dynamic> json) {
    return RideBike(
      id: json['_id'] as String? ?? '',
      code: json['code'] as String? ?? 'Unknown Bike',
    );
  }

  // Add toJson method for RideBike
  Map<String, dynamic> toJson() {
    return {'_id': id, 'code': code};
  }
}

class RideStation {
  final String id;
  final String name;

  RideStation({required this.id, required this.name});

  factory RideStation.fromJson(Map<String, dynamic> json) {
    return RideStation(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Station',
    );
  }

  // Add toJson method for RideStation
  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name};
  }
}

class Ride {
  final String id; // Add id for the ride itself
  final RideUser user;
  final RideBike bike;
  final RideStation?
  startStation; // Can be null if ride starts without a station
  final RideStation?
  destinationStation; // Can be null if ride ends without a station
  final double fare;
  final DateTime startTime;
  final DateTime? endTime; // End time can be null for ongoing rides
  final String status; // 'ongoing', 'completed'
  final double? distance; // Optional, if calculated
  final double? penaltyAmount; // Optional, if penalty is applied

  Ride({
    required this.id,
    required this.user,
    required this.bike, // This is the RideBike object
    this.startStation,
    this.destinationStation,
    required this.fare,
    required this.startTime,
    this.endTime,
    required this.status,
    this.distance,
    this.penaltyAmount,
    // REMOVED: required String bikeId, // This was redundant with 'bike'
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['_id'] as String? ?? '',
      user: RideUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      bike: RideBike.fromJson(json['bike'] as Map<String, dynamic>? ?? {}),
      startStation: (json['startStation'] is Map)
          ? RideStation.fromJson(json['startStation'] as Map<String, dynamic>)
          : null,
      destinationStation: (json['destinationStation'] is Map)
          ? RideStation.fromJson(
              json['destinationStation'] as Map<String, dynamic>,
            )
          : null,
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: (json['endTime'] != null && json['endTime'] is String)
          ? DateTime.parse(json['endTime'] as String)
          : null,
      status: json['status'] as String? ?? 'unknown',
      distance: (json['distance'] as num?)?.toDouble(),
      penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user': user.toJson(),
      'bike': bike.toJson(),
      'startStation': startStation?.toJson(),
      'destinationStation': destinationStation?.toJson(),
      'fare': fare,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status,
      'distance': distance,
      'penaltyAmount': penaltyAmount,
    };
  }
}
