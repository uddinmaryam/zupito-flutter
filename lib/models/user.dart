import 'package:flutter/material.dart'; // Not strictly needed for model, but often included

class User {
  final String id;
  final String username; // Changed from 'name' to 'username' to match backend
  final String email;
  final String? phone; // Assuming phone might be optional
  final bool isBlocked; // Assuming you have this field for admin control
  final double walletBalance;
  final DateTime
  createdAt; // Changed to createdAt to match backend's typical field name

  User({
    required this.id,
    required this.username,
    required this.email,
    this.phone, // Made optional
    required this.isBlocked,
    required this.walletBalance,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] as String? ?? '', // Use as String? and provide default
      username:
          json['username'] as String? ?? '', // Backend likely sends 'username'
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?, // Nullable
      isBlocked: json['isBlocked'] as bool? ?? false, // Default to false
      walletBalance:
          (json['walletBalance'] as num?)?.toDouble() ??
          0.0, // Handle num and default
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(), // Parse string to DateTime
    );
  }

  get name => null;

  // Optional: toJson method if you ever need to send User objects back to the backend
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'isBlocked': isBlocked,
      'walletBalance': walletBalance,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
