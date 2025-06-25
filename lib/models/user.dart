class RideHistoryEntry {
  final String bikeId;
  final double fare;
  final DateTime date;

  RideHistoryEntry({
    required this.bikeId,
    required this.fare,
    required this.date,
  });

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RideHistoryEntry(
      bikeId: json['bikeId'],
      fare: (json['fare'] as num).toDouble(),
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bikeId': bikeId,
      'fare': fare,
      'date': date.toIso8601String(),
    };
  }
}

class UserProfile {
  double totalFare;
  int totalRides;
  List<RideHistoryEntry> rideHistory;

  UserProfile({
    this.totalFare = 0.0,
    this.totalRides = 0,
    List<RideHistoryEntry>? rideHistory,
  }) : rideHistory = rideHistory ?? [];

  void addRide(String bikeId, double fare) {
    totalRides++;
    totalFare += fare;
    rideHistory.add(
      RideHistoryEntry(bikeId: bikeId, fare: fare, date: DateTime.now()),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      totalFare: (json['totalFare'] as num?)?.toDouble() ?? 0.0,
      totalRides: json['totalRides'] ?? 0,
      rideHistory: (json['rideHistory'] as List<dynamic>?)
              ?.map((e) => RideHistoryEntry.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalFare': totalFare,
      'totalRides': totalRides,
      'rideHistory': rideHistory.map((e) => e.toJson()).toList(),
    };
  }
}
