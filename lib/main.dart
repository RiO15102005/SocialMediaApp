// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'firebase_options.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase (Giữ nguyên)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Khởi tạo Supabase (Đã điền thông tin của bạn)
  await Supabase.initialize(
    url: 'https://okxqoqoosfyljmnmitif.supabase.co',
    anonKey: 'sb_publishable_sxoTBmL23HrUaYA6Nrbx_Q_alsyRlja',
  );

  // 3. Cấu hình timeago (Giữ nguyên)
  timeago.setLocaleMessages('vi', timeago.ViMessages());
  timeago.setDefaultLocale('vi');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joinly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}