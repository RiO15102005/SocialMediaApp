import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarUploadService {
  static final _client = Supabase.instance.client;

  // -----------------------------
  // UPLOAD AVATAR — FIX 100%
  // -----------------------------
  static Future<String?> uploadAvatar(String path, String userId) async {
    final file = File(path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = "avatar_${userId}_$timestamp.png"; // ⭐ đổi fileName → không cache

    try {
      await _client.storage.from("avatars").upload(
        fileName,
        file,
        fileOptions: const FileOptions(
          upsert: true,                 // ⭐ cho phép overwrite
          contentType: "image/png",
        ),
      );

      // ⭐ thêm query tránh cache CDN
      final rawUrl = _client.storage.from("avatars").getPublicUrl(fileName);
      final finalUrl = "$rawUrl?t=$timestamp";

      return finalUrl;
    } catch (e) {
      print("UPLOAD AVATAR ERROR: $e");
      return null;
    }
  }

  // -----------------------------
  // UPLOAD COVER — FIX 100%
  // -----------------------------
  static Future<String?> uploadCover(String path, String userId) async {
    final file = File(path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = "cover_${userId}_$timestamp.png"; // ⭐ đổi fileName mới

    try {
      await _client.storage.from("avatars").upload(
        fileName,
        file,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: "image/png",
        ),
      );

      final rawUrl = _client.storage.from("avatars").getPublicUrl(fileName);
      final finalUrl = "$rawUrl?t=$timestamp"; // ⭐ tránh cache

      return finalUrl;
    } catch (e) {
      print("UPLOAD COVER ERROR: $e");
      return null;
    }
  }
}
