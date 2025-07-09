import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap; // New: Optional callback for tap events

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.onTap, // New: Initialize the onTap callback
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // New: Wrap the Card with InkWell to make it tappable
      child: InkWell(
        onTap: onTap, // Assign the onTap callback here
        borderRadius: BorderRadius.circular(
          12,
        ), // Match the card's border radius
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
