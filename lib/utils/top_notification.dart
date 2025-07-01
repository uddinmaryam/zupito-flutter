import 'package:flutter/material.dart';

void showTopNotification(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            offset: Offset.zero,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Material(
                elevation: 12,
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  Future.delayed(const Duration(seconds: 30), () {
    entry.remove();
  });
}
