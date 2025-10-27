// lib/screens/main_layout_screen.dart

import 'package:flutter/material.dart';
import 'package:zalo_app/screens/home_screen.dart';
import 'package:zalo_app/screens/profile_screen.dart';
import 'package:zalo_app/screens/search_screen.dart';
import 'package:zalo_app/screens/chat_list_screen.dart';
import 'package:zalo_app/screens/notifications_screen.dart'; // Import NotificationsScreen

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  // Thêm NotificationsScreen vào danh sách
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    ChatListScreen(),
    SearchScreen(),
    NotificationsScreen(), // Màn hình mới
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Bảng tin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Nhắn tin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Tìm kiếm',
          ),
          // Thêm mục "Thông báo" vào thanh điều hướng
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Thông báo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
