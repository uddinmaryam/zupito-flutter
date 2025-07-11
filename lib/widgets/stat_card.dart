import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap; // Optional callback for tap events
  final IconData? icon; // New: Optional icon to display
  final Color? color; // New: Optional color for the card's elements

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    this.icon, // Initialize the new icon property
    this.color, // Initialize the new color property
  });

  @override
  Widget build(BuildContext context) {
    // Determine the color for the icon and value text, default to blueAccent if not provided
    final cardColor = color ?? Colors.blueAccent;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Wrap the Card with InkWell to make it tappable
      child: InkWell(
        onTap: onTap, // Assign the onTap callback here
        borderRadius: BorderRadius.circular(12), // Match the card's border radius
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display the icon if provided
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 40,
                  color: cardColor, // Use the provided or default color
                ),
                const SizedBox(height: 10),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: cardColor, // Use the provided or default color
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.black87), // Keep title text color consistent
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
