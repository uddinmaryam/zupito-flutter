import 'package:flutter/material.dart';
import 'package:zupito/models/user.dart'; // Import the User model

class UserCard extends StatelessWidget {
  final User user; // Now accepts a User object

  const UserCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3, // Added elevation for better visual depth
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.username, // Use user.username from the User model
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                    overflow: TextOverflow.ellipsis, // Handle long usernames
                  ),
                ),
                // Display block status with a visual indicator
                if (user.isBlocked) // Conditionally display if user is blocked
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'BLOCKED',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.email, // Use user.email
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (user.phone != null && user.phone!.isNotEmpty) ...[
              // Conditionally display phone
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user.phone!, // Use user.phone
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Wallet: \$${user.walletBalance.toStringAsFixed(2)}', // Use user.walletBalance
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                // Display joined date
                Text(
                  'Joined: ${user.createdAt.toLocal().toString().split(' ')[0]}', // Use user.createdAt and format
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            // You can add more details or actions here, e.g., an "Edit" button
            // or a button to toggle 'isBlocked' status (requires backend endpoint)
          ],
        ),
      ),
    );
  }
}
