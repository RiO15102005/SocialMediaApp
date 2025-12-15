import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/post_model.dart';
import '../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  final Post? post;

  const CreatePostScreen({super.key, this.post});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final PostService _postService = PostService();
  bool _isLoading = false;
  File? _imageFile;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _textController.text = widget.post!.content;
      _existingImageUrl = widget.post!.imageUrl;
    } else {
      _restoreDraft();
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          // Khi chọn ảnh mới, ta không còn giữ ảnh cũ nữa.
          _existingImageUrl = null; 
        });
      }
    } catch (e) {
      log('Failed to pick image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _existingImageUrl = null;
    });
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString('draft_post_content');
      if (draft != null && mounted) {
        _textController.text = draft;
      }
    } catch (e) {
      log('Failed to restore post draft: $e');
    }
  }

  Future<void> _saveDraft() async {
    if (widget.post == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('draft_post_content', _textController.text);
      } catch (e) {
        log('Failed to save post draft: $e');
      }
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_post_content');
    } catch (e) {
      log('Failed to clear post draft: $e');
    }
  }

  Future<void> _submitPost() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _imageFile == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy viết gì đó hoặc chọn ảnh để đăng.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.post != null) {
        bool imageWasRemoved = widget.post!.imageUrl != null && _existingImageUrl == null && _imageFile == null;
        
        await _postService.updatePost(
          widget.post!.postId,
          content,
          newImage: _imageFile,
          imageRemoved: imageWasRemoved,
        );
      } else {
        await _postService.createPost(content: content, imageFile: _imageFile);
      }

      await _clearDraft();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.post != null
                ? 'Cập nhật bài viết thành công!'
                : 'Đăng bài thành công!')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    if (!_isLoading && widget.post == null) {
      _saveDraft();
    }
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContent = _textController.text.isNotEmpty;
    final bool hasImage = _imageFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    final bool canPost = hasContent || hasImage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.post != null ? 'Chỉnh sửa bài viết' : 'Tạo bài viết',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: (_isLoading || !canPost) ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    widget.post != null ? 'LƯU' : 'ĐĂNG',
                    style: TextStyle(
                      color: (_isLoading || !canPost)
                          ? Colors.white54
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textController,
                    onChanged: (text) => setState(() {}),
                    autofocus: true,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText: 'Bạn đang nghĩ gì?',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasImage)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        if (_imageFile != null)
                          Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        else if (_existingImageUrl != null)
                          Image.network(
                            _existingImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        IconButton(
                          icon: const CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                          onPressed: _removeImage,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library),
                  onPressed: _pickImage,
                  tooltip: 'Chọn ảnh',
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
