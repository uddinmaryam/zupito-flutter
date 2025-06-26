import 'package:flutter/material.dart';
import '../../../models/user.dart';

void showUserProfilePanel(BuildContext context, UserProfile profile) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: Material(
            color: Colors.white,
            elevation: 12,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.indigo.shade100,
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      profile.email,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(profile.membershipLevel),
                      backgroundColor: Colors.indigo.shade100,
                      avatar: const Icon(
                        Icons.verified,
                        size: 18,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 25),
                    _profileStat(
                      "Wallet Balance",
                      "Rs. ${profile.walletBalance.toStringAsFixed(2)}",
                    ),
                    _profileStat("Total Rides", profile.totalRides.toString()),
                    _profileStat(
                      "Total Distance",
                      "${profile.totalDistance.toStringAsFixed(2)} km",
                    ),
                    _profileStat(
                      "Joined",
                      profile.joinedDate.toLocal().toString().split(' ')[0],
                    ),
                    const Spacer(),
                    _actionButton(Icons.edit, "Edit Profile", onPressed: () {}),
                    _actionButton(
                      Icons.history,
                      "Ride History",
                      onPressed: () {},
                    ),
                    _actionButton(Icons.logout, "Logout", onPressed: () {}),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text(
                        "Close",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _profileStat(String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

Widget _actionButton(
  IconData icon,
  String label, {
  required VoidCallback onPressed,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        minimumSize: const Size.fromHeight(45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
