import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Colors.indigo;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            // Use MainAxisSize.min to allow the Column to take only the space its children need
            // combined with FittedBox/Flexible children, this helps prevent overflow.
            mainAxisSize: MainAxisSize
                .min, // Crucial for flex children in constrained spaces
            children: [
              // MARKER: This text MUST appear on every StatCard if this code is active.
              //const Text('SC_FIX_V2', style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),

              if (icon != null) ...[
                Icon(icon, size: 40, color: cardColor),
                const SizedBox(height: 10),
              ],
              // Use Flexible and FittedBox for the value to ensure it scales down
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Use Flexible for the title to allow it to wrap and truncate
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
