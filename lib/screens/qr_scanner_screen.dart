import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:zupito/models/bike.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isScanned = false;

  final List<Bike> _bikes = [
    Bike(
      id: 'B1',
      name: 'Zupito A',
      lat: 27.6775,
      lng: 85.3160,
      pricePerMinute: 2.0,
      isAvailable: true,
    ),
    Bike(
      id: 'B2',
      name: 'Zupito B',
      lat: 27.6760,
      lng: 85.3172,
      pricePerMinute: 1.5,
      isAvailable: false,
    ),
    Bike(
      id: 'B3',
      name: 'Zupito C',
      lat: 27.6748,
      lng: 85.3185,
      pricePerMinute: 1.8,
      isAvailable: true,
    ),
    Bike(
      id: 'B4',
      name: 'Zupito D',
      lat: 27.6783,
      lng: 85.3132,
      pricePerMinute: 2.2,
      isAvailable: false,
    ),
    Bike(
      id: 'B5',
      name: 'Zupito E',
      lat: 27.6722,
      lng: 85.3145,
      pricePerMinute: 1.7,
      isAvailable: true,
    ),
    Bike(
      id: 'B6',
      name: 'Zupito F',
      lat: 27.6798,
      lng: 85.3190,
      pricePerMinute: 2.1,
      isAvailable: false,
    ),
  ];

  @override
  void reassemble() {
    super.reassemble();
    controller?.pauseCamera();
    controller?.resumeCamera();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) {
      if (!isScanned) {
        isScanned = true;
        controller.pauseCamera();

        final rawCode = scanData.code;
        if (rawCode == null || rawCode.trim().isEmpty) {
          _showDialog("❌ Invalid QR Code", "QR Code is empty or unreadable.");
          return;
        }

        final scannedId = rawCode.trim().toUpperCase();
        print('Scanned QR Code data: "$scannedId"');
        print('Available bike IDs: ${_bikes.map((b) => b.id).join(', ')}');

        Bike? matchedBike;
        try {
          matchedBike = _bikes.firstWhere(
            (bike) => bike.id.toUpperCase() == scannedId,
          );
        } catch (e) {
          matchedBike = null;
        }

        if (matchedBike == null) {
          _showDialog("❌ Invalid QR Code", "This bike does not exist.");
        } else if (!matchedBike.isAvailable) {
          _showDialog(
            "🚫 Bike Not Available",
            "This bike is currently in use.",
          );
        } else {
          _showDialog(
            "✅ Bike Available",
            "You can now start your ride on ${matchedBike.name}.",
          );
        }
      }
    });
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await controller?.stopCamera(); // Stop camera (force reset)
              await controller?.resumeCamera(); // Restart it again
              isScanned = false; // Allow scanning again
            },
          ),
        ],
      ),
    ).then((_) {
      isScanned = false;
      controller?.resumeCamera();
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: Colors.orange,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
    );
  }
}
