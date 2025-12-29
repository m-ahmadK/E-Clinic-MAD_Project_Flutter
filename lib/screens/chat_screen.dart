import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/cloudinary_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  // IDs
  late String _currentUserId;
  late String _targetUserId;
  late String _chatRoomId;
  String? _targetUserName;
  String? _targetUserImage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 1. Get Arguments
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = user!.uid;

    if (args['isPatientView'] == true) {
      _targetUserId = args['doctorId'];
      _targetUserName = args['doctorName'];
    } else {
      _targetUserId = args['patientId'];
      _targetUserName = args['patientName'] ?? "Patient";
    }

    // 2. Generate Chat Room ID
    List<String> ids = [_currentUserId, _targetUserId];
    ids.sort();
    _chatRoomId = ids.join("_");

    _fetchTargetUserProfile();
  }

  Future<void> _fetchTargetUserProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
    if (doc.exists && mounted) {
      setState(() {
        final data = doc.data() as Map<String, dynamic>;
        _targetUserImage = data['profileImage'] ?? data['imageUrl'];
      });
    }
  }

  // --- FIXED: SEND TEXT MESSAGE ---
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    // 1. Add to Sub-Collection (The actual history)
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatRoomId)
        .collection('messages')
        .add({
      'senderId': _currentUserId,
      'text': messageText,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. UPDATE PARENT DOCUMENT (This makes it appear in the List!)
    await FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).set({
      'lastMessage': messageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [_currentUserId, _targetUserId],
    }, SetOptions(merge: true));

    _scrollToBottom();
  }

  // --- FIXED: SEND IMAGE MESSAGE ---
  Future<void> _sendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      String? imageUrl = await CloudinaryService().uploadImage(File(image.path));

      if (imageUrl != null) {
        // 1. Add Message
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatRoomId)
            .collection('messages')
            .add({
          'senderId': _currentUserId,
          'imageUrl': imageUrl,
          'text': "Sent an image",
          'type': 'image',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 2. UPDATE PARENT DOCUMENT
        await FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).set({
          'lastMessage': "📷 Sent an image",
          'lastMessageTime': FieldValue.serverTimestamp(),
          'participants': [_currentUserId, _targetUserId],
        }, SetOptions(merge: true));

        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final inputFill = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _targetUserImage != null
                  ? CachedNetworkImageProvider(_targetUserImage!)
                  : null,
              child: _targetUserImage == null
                  ? const Icon(Icons.person, size: 20, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _targetUserName ?? "Chat",
                style: const TextStyle(color: Colors.white, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        Text("Start the conversation!", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == _currentUserId;
                    return _buildMessageBubble(data, isMe, isDark);
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text("Sending image...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: inputFill,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image, color: Colors.blueAccent),
                    onPressed: _sendImage,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, bool isDark) {
    final myBubbleColor = Colors.blueAccent;
    final otherBubbleColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final myTextColor = Colors.white;
    final otherTextColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[300],
              backgroundImage: _targetUserImage != null
                  ? CachedNetworkImageProvider(_targetUserImage!)
                  : null,
              child: _targetUserImage == null
                  ? const Icon(Icons.person, size: 16, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: data['type'] == 'image'
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? myBubbleColor : otherBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  if (!isMe && !isDark)
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(1, 1))
                ],
              ),
              child: data['type'] == 'image'
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: data['imageUrl'],
                  height: 200,
                  width: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200, width: 200,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              )
                  : Text(
                data['text'] ?? "",
                style: TextStyle(
                  color: isMe ? myTextColor : otherTextColor,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}