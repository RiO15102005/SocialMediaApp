// lib/screens/search_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zalo_app/screens/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Stream<QuerySnapshot>? _usersStream;
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
        _updateSearchStream();
      });
    });
  }

  void _updateSearchStream() {
    if (_searchText.isNotEmpty) {
      String lowerCaseSearchText = _searchText.toLowerCase();

      _usersStream = FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: lowerCaseSearchText)
          .where('email', isLessThanOrEqualTo: '$lowerCaseSearchText\uf8ff')
          .snapshots();
    } else {
      _usersStream = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm bạn bè'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo email...',
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (_searchText.isEmpty) {
                  return const Center(child: Text('Nhập email để tìm kiếm bạn bè.'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Đã xảy ra lỗi!'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Không tìm thấy người dùng nào.'));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final userData = doc.data() as Map<String, dynamic>;
                    // Don't show the current user in the search results
                    if (userData['uid'] == FirebaseAuth.instance.currentUser?.uid) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(userData['displayName']?.isNotEmpty == true
                          ? userData['displayName']
                          : userData['email']),
                      subtitle: Text(userData['email']),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ProfileScreen(userId: userData['uid']),
                        ));
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
