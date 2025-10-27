import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/main_layout_screen.dart';
import 'package:zalo_app/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  // Thêm const constructor để code sạch hơn
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Thêm một bước kiểm tra trạng thái kết nối cho mượt hơn
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Nếu snapshot có dữ liệu (user không phải null), nghĩa là người dùng đã đăng nhập
          if (snapshot.hasData) {
            // Thay HomeScreen bằng MainLayoutScreen
            return const MainLayoutScreen();
          } else {
            // Nếu snapshot không có dữ liệu (user là null), nghĩa là người dùng chưa đăng nhập
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
