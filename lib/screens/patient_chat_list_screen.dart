import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class PatientChatListScreen extends StatelessWidget {
  const PatientChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Theme Variables
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[100];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("My Chats", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent, // Blue App Bar
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to all chats ordered by time
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

          // Filter: Find chats where the Document ID contains the Patient's UID
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

              // Logic to find the "Other" person (The Doctor)
              final parts = chatRoomId.split('_');
              final otherUserId = parts[0] == currentUserId ? parts[1] : parts[0];

              // Fetch the DOCTOR'S Info
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();

                  final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final String name = userData['name'] ?? "Doctor";
                  final String? image = userData['profileImage'] ?? userData['imageUrl'];

                  return Card(
                    color: cardColor,
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
                        "Dr. $name",
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
                        // Navigate to Chat Screen
                        Navigator.pushNamed(context, '/chat_screen', arguments: {
                          'patientId': currentUserId, // Me
                          'doctorId': otherUserId,    // Them
                          'doctorName': "Dr. $name",
                          'isPatientView': true,      // I am the patient
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
          Text("No active chats", style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }
}