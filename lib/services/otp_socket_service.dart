import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class OtpSocketService {
  static final OtpSocketService _instance = OtpSocketService._internal();
  factory OtpSocketService() => _instance;
  OtpSocketService._internal();

  late IO.Socket socket;
  bool _isConnected = false;

  void connect(String userId, {required BuildContext context}) {
    if (_isConnected) return;

    socket = IO.io('https://backend-bicycle-1.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'Access-Control-Allow-Origin': '*'},
    });

    socket.connect();

    socket.onConnect((_) {
      _isConnected = true;
      print('✅ Connected to WebSocket');
      print('📡 Registering socket with userId: $userId'); // <-- 👈 ADDED LINE
      socket.emit('register', userId);
    });

    socket.on('otp', (data) {
      print("🔐 OTP received: ${data['otp']} for bike ${data['bikeCode']}");

      final otp = data['otp'];
      final bike = data['bikeCode'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🔐 OTP for $bike: $otp"),
          duration: const Duration(seconds: 10),
        ),
      );
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
