import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../widgets/chat_bubble.dart';
import 'group_info_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';
import 'create_group_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    this.isGroup = false
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String? _replyingMessage;
  String? _replyingName;

  late String chatRoomId;
  late String uid;

  // Search Variables
  bool _isSearching = false;
  final TextEditingController _searchBarController = TextEditingController();
  List<int> _searchResultsIndexes = [];
  int _currentSearchIndex = 0;
  List<QueryDocumentSnapshot> _allDocs = [];
  List<String> _filterSenderIds = [];

  // Đa phương tiện
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    uid = _auth.currentUser!.uid;
    chatRoomId = widget.isGroup ? widget.receiverId : _chatService.getChatRoomId(uid, widget.receiverId);
    _updateLastReadTime();
  }

  @override
  void dispose() {
    _updateLastReadTime();
    _messageController.dispose();
    _scrollController.dispose();
    _searchBarController.dispose();
    super.dispose();
  }

  Future<void> _updateLastReadTime() async {
    await FirebaseFirestore.instance.collection("chat_rooms").doc(chatRoomId).set(
        {"lastReadTime": {uid: FieldValue.serverTimestamp()}}, SetOptions(merge: true));
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _scrollToIndex(int index) {
    if (_scrollController.hasClients) {
      double estimatedOffset = index * 70.0;
      _scrollController.animateTo(estimatedOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() { _searchResultsIndexes.clear(); _currentSearchIndex = 0; });
      return;
    }
    List<int> results = [];
    for (int i = 0; i < _allDocs.length; i++) {
      final data = _allDocs[i].data() as Map<String, dynamic>;
      final message = (data['message'] ?? "").toString().toLowerCase();
      final senderId = data['senderId'];
      bool senderMatch = true;
      if (widget.isGroup && _filterSenderIds.isNotEmpty) {
        if (!_filterSenderIds.contains(senderId)) senderMatch = false;
      }
      if (message.contains(query.toLowerCase()) && senderMatch) {
        results.add(i);
      }
    }
    setState(() { _searchResultsIndexes = results; _currentSearchIndex = 0; });
    if (results.isNotEmpty) { _scrollToIndex(results[0]); }
  }

  void _nextSearchResult() {
    if (_searchResultsIndexes.isEmpty) return;
    setState(() {
      if (_currentSearchIndex < _searchResultsIndexes.length - 1) {
        _currentSearchIndex++;
        _scrollToIndex(_searchResultsIndexes[_currentSearchIndex]);
      }
    });
  }

  void _prevSearchResult() {
    if (_searchResultsIndexes.isEmpty) return;
    setState(() {
      if (_currentSearchIndex > 0) {
        _currentSearchIndex--;
        _scrollToIndex(_searchResultsIndexes[_currentSearchIndex]);
      }
    });
  }

  void _showFilterSenderDialog() async {
    final groupDoc = await FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).get();
    final participants = List<String>.from(groupDoc.data()?['participants'] ?? []);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        List<String> tempSelected = List.from(_filterSenderIds);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Lọc theo người gửi"),
              content: SizedBox(
                width: double.maxFinite, height: 300,
                child: ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final uid = participants[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        final user = snap.data!.data() as Map<String, dynamic>;
                        final name = user['displayName'] ?? "Thành viên";
                        return CheckboxListTile(
                          title: Text(name),
                          value: tempSelected.contains(uid),
                          onChanged: (val) {
                            setStateDialog(() { if (val == true) tempSelected.add(uid); else tempSelected.remove(uid); });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                TextButton(onPressed: () { setState(() { _filterSenderIds = tempSelected; }); _performSearch(_searchBarController.text); Navigator.pop(ctx); }, child: const Text("OK")),
              ],
            );
          },
        );
      },
    );
  }

  // ⭐ Gửi tin nhắn (Text + Ảnh)
  void sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty) return;

    final replyTo = _replyingMessage;
    final replyName = _replyingName;

    _messageController.clear();
    List<XFile> imagesToSend = List.from(_selectedImages);
    setState(() {
      _selectedImages.clear();
      _replyingMessage = null;
      _replyingName = null;
    });

    if (text.isNotEmpty) {
      await _chatService.sendMessage(widget.receiverId, text, isGroup: widget.isGroup, replyToMessage: replyTo, replyToName: replyName);
    }

    if (imagesToSend.isNotEmpty) {
      for (var image in imagesToSend) {
        final isFirstImageAndNoText = (text.isEmpty && imagesToSend.first == image);
        await _chatService.sendImageMessage(
            widget.receiverId,
            File(image.path),
            isGroup: widget.isGroup,
            replyToMessage: isFirstImageAndNoText ? replyTo : null,
            replyToName: isFirstImageAndNoText ? replyName : null
        );
      }
    }

    _updateLastReadTime();
    _scrollToBottom();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
      _scrollToBottom();
    }
  }

  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _onReplyTriggered(String msg, String senderId) async {
    String senderName = "Người dùng";
    if (senderId == uid) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      senderName = doc.data()?['displayName'] ?? "Tôi";
    } else {
      if (!widget.isGroup && senderId == widget.receiverId) {
        senderName = widget.receiverName;
      } else {
        final doc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
        senderName = doc.data()?['displayName'] ?? "Thành viên";
      }
    }
    setState(() { _replyingMessage = msg; _replyingName = senderName; });
  }

  void _handleReaction(String msgId, Map<String, dynamic> currentReactions, String newReaction) {
    if (currentReactions[uid] == newReaction) _chatService.removeReaction(chatRoomId, msgId);
    else _chatService.sendReaction(chatRoomId, msgId, newReaction);
  }

  void _showReactionDetailsDialog(Map<String, dynamic> reactions) {
    showDialog(context: context, builder: (context) {
      final iconMap = {'like': '👍', 'love': '❤️', 'haha': '😂', 'sad': '😢'};
      return AlertDialog(title: const Text("Cảm xúc"), content: SizedBox(width: double.maxFinite, height: 300, child: ListView.builder(itemCount: reactions.length, itemBuilder: (context, index) { String userId = reactions.keys.elementAt(index); String type = reactions.values.elementAt(index); return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(userId).get(), builder: (context, snapshot) { if (!snapshot.hasData) return const SizedBox.shrink(); final data = snapshot.data!.data() as Map<String, dynamic>?; return ListTile(leading: CircleAvatar(backgroundImage: (data?['photoURL'] != null) ? NetworkImage(data!['photoURL']) : null, child: (data?['photoURL'] == null) ? const Icon(Icons.person) : null), title: Text(data?['displayName'] ?? 'Người dùng'), trailing: Text(iconMap[type] ?? '', style: const TextStyle(fontSize: 20))); }); })), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))]);
    });
  }

  Future<void> _confirmRecall(String msgId) async { final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Thu hồi?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Thu hồi", style: TextStyle(color: Colors.red)))])); if (ok == true) await _chatService.recallMessage(chatRoomId, msgId); }
  Future<void> _confirmDeleteForMe(String msgId) async { final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Xóa cho bạn?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xóa", style: TextStyle(color: Colors.red)))])); if (ok == true) await _chatService.deleteMessageForMe(chatRoomId, msgId); }
  Future<void> _confirmDeleteChat() async { final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Xóa đoạn chat?"), content: const Text("Hành động này không thể hoàn tác."), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xóa", style: TextStyle(color: Colors.red)))])); if (confirm == true) { await _chatService.hideChatRoom(chatRoomId); if (mounted) Navigator.popUntil(context, (route) => route.isFirst); } }
  void _navigateToProfile() { if (!widget.isGroup) Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.receiverId))); }
  void _showAddToGroupDialog() { showDialog(context: context, builder: (context) { return AlertDialog(title: const Text("Chọn nhóm để thêm vào"), content: SizedBox(width: double.maxFinite, height: 300, child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chat_rooms').where('participants', arrayContains: uid).where('isGroup', isEqualTo: true).snapshots(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator()); if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Bạn chưa tham gia nhóm nào.")); final groups = snapshot.data!.docs; return ListView.builder(itemCount: groups.length, itemBuilder: (context, index) { final groupData = groups[index].data() as Map<String, dynamic>; final groupId = groups[index].id; final groupName = groupData['groupName'] ?? 'Nhóm'; final participants = List<String>.from(groupData['participants'] ?? []); final isMember = participants.contains(widget.receiverId); return ListTile(leading: const CircleAvatar(child: Icon(Icons.groups)), title: Text(groupName), subtitle: isMember ? const Text("Đã là thành viên", style: TextStyle(fontSize: 12)) : null, onTap: isMember ? null : () async { Navigator.pop(context); await _chatService.addMembersToGroup(groupId, [widget.receiverId]); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã thêm vào nhóm $groupName"))); }); }); })), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng"))]); }); }
  void _showOptionsBottomSheet() { showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), isScrollControlled: true, builder: (context) { return Container(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [Center(child: Column(children: [CircleAvatar(radius: 40, backgroundImage: (widget.receiverAvatar != null && widget.receiverAvatar!.isNotEmpty) ? NetworkImage(widget.receiverAvatar!) : null, child: (widget.receiverAvatar == null || widget.receiverAvatar!.isEmpty) ? const Icon(Icons.person, size: 40) : null), const SizedBox(height: 10), Text(widget.receiverName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), TextButton(onPressed: () {Navigator.pop(context); _navigateToProfile();}, child: const Text("Xem trang cá nhân", style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.w600)))])), const Divider(), ListTile(leading: const Icon(Icons.group_add_outlined), title: const Text("Tạo nhóm với người này"), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => CreateGroupScreen(preSelectedUserId: widget.receiverId)));}), ListTile(leading: const Icon(Icons.person_add_alt), title: const Text("Thêm người này vào nhóm"), onTap: () {Navigator.pop(context); _showAddToGroupDialog();}), const Divider(), ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text("Xóa đoạn chat", style: TextStyle(color: Colors.red)), onTap: () {Navigator.pop(context); _confirmDeleteChat();})])); }); }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchBarController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(hintText: "Tìm kiếm tin nhắn...", hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
      onChanged: (val) { _performSearch(val); },
    );
  }

  Widget _buildSearchControlPanel() {
    if (!_isSearching) return const SizedBox.shrink();
    if (_searchBarController.text.isNotEmpty && _searchResultsIndexes.isEmpty) return Container(color: Colors.grey[200], padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: const Text("Không có tin nhắn trùng khớp", style: TextStyle(color: Colors.red)));
    if (_searchResultsIndexes.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.grey[200], padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Text("${_currentSearchIndex + 1}/${_searchResultsIndexes.length} kết quả", style: const TextStyle(fontWeight: FontWeight.bold)), if (widget.isGroup) ...[const SizedBox(width: 8), IconButton(icon: const Icon(Icons.person_search), tooltip: "Lọc theo người gửi", onPressed: _showFilterSenderDialog)]]),
        Row(children: [IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: _nextSearchResult), IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: _prevSearchResult)]),
      ]),
    );
  }

  // ⭐ UI BUILD - NESTED STREAM BUILDER
  @override
  Widget build(BuildContext context) {
    uid = _auth.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: const BackButton(),
        backgroundColor: const Color(0xFF1877F2), foregroundColor: Colors.white,
        title: _isSearching
            ? _buildSearchField()
            : GestureDetector(onTap: _navigateToProfile, child: Row(children: [CircleAvatar(backgroundImage: (widget.receiverAvatar != null && widget.receiverAvatar!.isNotEmpty) ? NetworkImage(widget.receiverAvatar!) : null, child: (widget.receiverAvatar == null || widget.receiverAvatar!.isEmpty) ? Icon(widget.isGroup ? Icons.groups : Icons.person) : null), const SizedBox(width: 10), Expanded(child: Text(widget.receiverName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))])),
        actions: [
          IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search), onPressed: () { setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchBarController.clear(); _searchResultsIndexes.clear(); _filterSenderIds.clear(); } }); }),
          if (!_isSearching) IconButton(icon: const Icon(Icons.menu), onPressed: () => widget.isGroup ? Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: chatRoomId, groupName: widget.receiverName))) : _showOptionsBottomSheet()),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // ⭐ STREAM 1: Lắng nghe Room để lấy joinTimes mới nhất
              child: widget.isGroup
                  ? StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).snapshots(),
                  builder: (context, roomSnap) {
                    Timestamp? myJoinTime;
                    if (roomSnap.hasData && roomSnap.data!.exists) {
                      final data = roomSnap.data!.data() as Map<String, dynamic>;
                      final joinTimes = data['joinTimes'] as Map<String, dynamic>?;
                      if (joinTimes != null && joinTimes.containsKey(uid)) {
                        myJoinTime = joinTimes[uid] as Timestamp?;
                      }
                    }

                    // ⭐ STREAM 2: Lấy tin nhắn dựa trên joinTime
                    return _buildMessageList(myJoinTime);
                  }
              )
                  : _buildMessageList(null) // Chat 1-1 không cần lọc
          ),

          // PHẦN NHẬP LIỆU (Giữ nguyên)
          Column(children: [
            _buildSearchControlPanel(),
            Container(
              padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyingMessage != null) Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Color(0xFF1877F2), width: 4))), child: Row(children: [const Icon(Icons.reply, size: 16, color: Color(0xFF1877F2)), const SizedBox(width: 8), Expanded(child: Text("Đang trả lời ${_replyingName ?? '...'}: $_replyingMessage", maxLines: 1, overflow: TextOverflow.ellipsis)), GestureDetector(onTap: () => setState(() { _replyingMessage = null; _replyingName = null; }), child: const Icon(Icons.close, size: 18))])),

                    // PREVIEW ẢNH
                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(image: FileImage(File(_selectedImages[index].path)), fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  top: 0, right: 8,
                                  child: GestureDetector(
                                    onTap: () => _removeSelectedImage(index),
                                    child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(icon: const Icon(Icons.image, color: Color(0xFF1877F2)), onPressed: _pickImages),
                          Expanded(child: TextField(controller: _messageController, maxLines: 4, minLines: 1, decoration: InputDecoration(hintText: "Nhập tin nhắn...", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)), onTap: _scrollToBottom)),
                          const SizedBox(width: 8),
                          CircleAvatar(backgroundColor: const Color(0xFF1877F2), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: sendMessage))
                        ]
                    )
                  ]),
            ),
          ])
        ],
      ),
    );
  }

  // Tách hàm build message list để tái sử dụng
  Widget _buildMessageList(Timestamp? joinTime) {
    return StreamBuilder<QuerySnapshot>(
        stream: _chatService.getMessages(chatRoomId, startAfter: joinTime),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          _allDocs = docs;

          bool needsUpdate = false;
          for (var doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final readBy = List<String>.from(d['readBy'] ?? []);
            if (!readBy.contains(uid)) { needsUpdate = true; break; }
          }
          if (needsUpdate) WidgetsBinding.instance.addPostFrameCallback((_) => _chatService.markMessagesAsRead(chatRoomId));

          return ListView.builder(
            controller: _scrollController, padding: const EdgeInsets.all(12), itemCount: docs.length,
            reverse: true,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              if ((data["deletedFor"] as List?)?.contains(uid) == true) return const SizedBox.shrink();

              bool isHighlighted = false;
              if (_isSearching && _searchResultsIndexes.isNotEmpty) {
                if (_searchResultsIndexes.contains(i)) {
                  if (i == _searchResultsIndexes[_currentSearchIndex]) { isHighlighted = true; }
                }
              }

              final type = data['type'] ?? 'text';
              if (type == 'system') return Container(alignment: Alignment.center, margin: const EdgeInsets.symmetric(vertical: 12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(20)), child: Text(data["message"] ?? "", style: const TextStyle(fontSize: 12, color: Colors.black54))));

              final isMe = data["senderId"] == uid;
              final isSharedPost = type == 'shared_post';
              final readByList = List<String>.from(data['readBy'] ?? []);
              final viewers = readByList.where((id) => id != data['senderId']).toList();
              final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
              final isRevoked = data["isRecalled"] == true;
              final displayMessage = isRevoked ? "Tin nhắn đã được thu hồi" : (data["message"] ?? "");

              return ChatBubble(
                message: displayMessage, isCurrentUser: isMe, timestamp: data["timestamp"] ?? Timestamp.now(), isRevoked: isRevoked, type: isSharedPost ? 'shared_post' : type, imageUrl: data['imageUrl'],
                replyToMessage: data['replyToMessage'], replyToName: data['replyToName'],
                readBy: viewers, isGroup: widget.isGroup, senderId: data['senderId'], senderAvatarUrl: (!isMe && !widget.isGroup) ? widget.receiverAvatar : null,
                reactions: reactions, onReactionTap: (reaction) => _handleReaction(docs[i].id, reactions, reaction), onViewReactions: () => _showReactionDetailsDialog(reactions), onLikePressed: () => _chatService.toggleLikeMessage(chatRoomId, docs[i].id),
                onRecall: isMe && data["isRecalled"] != true ? () => _confirmRecall(docs[i].id) : null, onDeleteForMe: () => _confirmDeleteForMe(docs[i].id),
                onReply: () => _onReplyTriggered((type == 'image') ? "[Hình ảnh]" : (data["message"] ?? ""), data['senderId']),
                sharedPostContent: data['sharedPostContent'], sharedPostUserName: data['sharedPostUserName'], onSharedPostTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(postId: data['postId']))); },
                isHighlighted: isHighlighted,
              );
            },
          );
        }
    );
  }
}