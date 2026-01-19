import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- THEME VARIABLES ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final headerColor = Colors.blueAccent;
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF222B45);

    // --- FIX APPLIED HERE: Added '!' ---
    final Color subTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6B779A);

    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login to view notifications")));
    }

    return Scaffold(
      backgroundColor: headerColor,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: headerColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // --- MAIN WHITE CONTAINER ---
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: user.uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Error Handling (Index Check)
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          "Needs Index! Check Console for Link.\nError: ${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subTextColor),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(subTextColor);
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    itemCount: docs.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 15),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildNotificationCard(data, cardColor, textColor, subTextColor);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildEmptyState(Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No notifications yet.", style: TextStyle(color: subTextColor, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data, Color cardColor, Color textColor, Color subTextColor) {
    final String title = data['title'] ?? "Notification";
    final String body = data['body'] ?? "";
    final Timestamp? timestamp = data['timestamp'];

    String timeStr = "Just now";
    if (timestamp != null) {
      final dt = timestamp.toDate();
      timeStr = DateFormat('MMM d, h:mm a').format(dt);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 15),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent.withOpacity(0.6)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                      height: 1.4
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}