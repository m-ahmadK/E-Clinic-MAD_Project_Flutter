import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Ensure you have this import
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class DoctorChatListScreen extends StatelessWidget {
  const DoctorChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Theme Variables
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: Text("My Messages", style: TextStyle(color: textColor)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Hide back button since it's a tab
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query logic: Fetch chats where the document ID contains the Doctor's UID
        // Note: A better way is to save an array 'participants': [uid1, uid2] in the chat doc
        // For now, we fetch the 'chats' collection.
        stream: FirebaseFirestore.instance
            .collection('chats')
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(subTextColor);
          }

          // Filter documents client-side to find ones belonging to this doctor
          // (Because Firestore doesn't support substring search on IDs easily)
          final myChats = snapshot.data!.docs.where((doc) {
            return doc.id.contains(currentUserId);
          }).toList();

          if (myChats.isEmpty) {
            return _buildEmptyState(subTextColor);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: myChats.length,
            itemBuilder: (context, index) {
              final chatData = myChats[index].data() as Map<String, dynamic>;
              final String chatRoomId = myChats[index].id;

              // Parse IDs from "uid1_uid2" to find the "Other" person
              final parts = chatRoomId.split('_');
              final otherUserId = parts[0] == currentUserId ? parts[1] : parts[0];

              // Fetch the Patient's Info to display name/image
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();

                  final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final String name = userData['name'] ?? "Patient";
                  final String? image = userData['profileImage'] ?? userData['imageUrl'];

                  return Card(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: image != null && image.isNotEmpty
                            ? CachedNetworkImageProvider(image)
                            : null,
                        child: image == null || image.isEmpty
                            ? const Icon(Icons.person, color: Colors.blueAccent)
                            : null,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      ),
                      subtitle: Text(
                        chatData['lastMessage'] ?? "Start a conversation",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subTextColor),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        // Navigate to the Chat Screen
                        Navigator.pushNamed(context, '/chat_screen', arguments: {
                          'patientId': otherUserId,
                          'patientName': name,
                          'doctorId': currentUserId, // Myself
                          'isPatientView': false, // Doctor is viewing
                        });
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Color? color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No messages yet", style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }
}