import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ⭐ Thêm Supabase
import 'firebase_options.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ⭐ Supabase init
  await Supabase.initialize(
    url: 'https://okxqoqoosfyljmnmitif.supabase.co',      // Thay bằng Project URL
    anonKey: 'sb_publishable_sxoTBmL23HrUaYA6Nrbx_Q_alsyRlja',             // Thay bằng anon key
  );

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
