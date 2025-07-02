import 'package:flutter/material.dart';

void showTopNotification(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 300),
  );

  final slideAnimation = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

  entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: SlideTransition(
            position: slideAnimation,
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
      );
    },
  );

  overlay.insert(entry);
  controller.forward();

  Future.delayed(const Duration(seconds: 3), () async {
    await controller.reverse();
    entry.remove();
    controller.dispose();
  });
}
