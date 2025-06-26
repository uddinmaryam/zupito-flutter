class UserProfile {
  final String id;
  final String name;
  final String email;
  final double walletBalance;
  final int totalRides;
  final double totalDistance;
  final String membershipLevel;
  final DateTime joinedDate;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.walletBalance,
    required this.totalRides,
    required this.totalDistance,
    required this.membershipLevel,
    required this.joinedDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      walletBalance: (json['walletBalance'] ?? 0).toDouble(),
      totalRides: json['totalRides'] ?? 0,
      totalDistance: (json['totalDistance'] ?? 0).toDouble(),
      membershipLevel: json['membershipLevel'] ?? 'Free',
      joinedDate: json['joinedDate'] != null
          ? DateTime.parse(json['joinedDate'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'walletBalance': walletBalance,
      'totalRides': totalRides,
      'totalDistance': totalDistance,
      'membershipLevel': membershipLevel,
      'joinedDate': joinedDate.toIso8601String(),
    };
  }
}
