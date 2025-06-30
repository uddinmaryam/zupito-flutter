import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class OtpSocketService {
  static final OtpSocketService _instance = OtpSocketService._internal();
  factory OtpSocketService() => _instance;
  OtpSocketService._internal();

  late IO.Socket socket;
  BuildContext? _context;
  bool _isConnected = false;

  void connect(String userId, {required BuildContext context}) {
    if (_isConnected) return;

    _context = context;

    socket = IO.io('https://backend-bicycle-1.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Access-Control-Allow-Origin': '*'},
    });

    socket.connect();

    socket.onConnect((_) {
      _isConnected = true;
      print('✅ Connected to WebSocket');
      print('📡 Registering socket with userId: $userId');
      socket.emit('register', userId);
    });

    socket.on('otp', (data) {
      final otp = data['otp'];
      final bike = data['bikeCode'];
      print("🔐 OTP received: $otp for bike $bike");

      if (_context != null) {
        showDialog(
          context: _context!,
          builder: (ctx) => AlertDialog(
            title: const Text("🔐 OTP Received"),
            content: Text("Your OTP for $bike is: $otp"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      print('🔌 Disconnected from WebSocket');
    });

    socket.onConnectError((err) {
      _isConnected = false;
      print('❌ Connect Error: $err');
    });

    socket.onError((err) {
      print('❌ Socket Error: $err');
    });
  }

  void disconnect() {
    if (_isConnected) {
      socket.disconnect();
      _isConnected = false;
      print('👋 Disconnected manually');
    }
  }
}
