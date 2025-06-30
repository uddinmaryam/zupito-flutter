class Ride {
  final String bikeId;
  final double fare;
  final DateTime startTime;
  final DateTime endTime;

  Ride({
    required this.bikeId,
    required this.fare,
    required this.startTime,
    required this.endTime,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      bikeId: json['bikeId'],
      fare: (json['fare'] as num).toDouble(),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bikeId': bikeId,
      'fare': fare,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }
}
