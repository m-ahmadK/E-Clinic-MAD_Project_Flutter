import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart'; // Ensure this path is correct

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key});

  // --- HELPER: Start Chat ---
  void _startChat(BuildContext context, String doctorId, String doctorName) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    // Navigate to Chat Screen
    Navigator.pushNamed(context, '/chat_screen', arguments: {
      'patientId': user.uid,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'isPatientView': true, // To indicate patient is viewing
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String doctorId = args['doctorId'];

    // --- 1. THEME VARIABLES ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final statBgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // --- UPDATED APP BAR ---
        title: const Text("Doctor Details", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent, // Blue Background
        iconTheme: const IconThemeData(color: Colors.white), // White Back Arrow
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Something went wrong", style: TextStyle(color: textColor)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Doctor not found", style: TextStyle(color: textColor)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // --- 2. DATA PARSING ---
          final name = (data['name'] ?? "Unknown Doctor").toString();
          final specialization = (data['specialization'] ?? "Specialist").toString();
          final bio = (data['bio'] ?? "This doctor has not added a bio yet.").toString();
          final experience = (data['experience'] ?? "5+").toString();
          final rating = (data['rating'] ?? "4.8").toString();
          final phone = (data['phone'] ?? "--").toString();
          final pmdcNumber = (data['pmdc_number'] ?? "--").toString();
          final startTiming = (data['start_timing'] ?? data['startTime'] ?? "10:00 AM").toString();
          final endTiming = (data['end_timing'] ?? data['endTime'] ?? "05:00 PM").toString();

          // --- 3. IMAGE LOGIC ---
          String displayImage = '';
          if (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty) {
            displayImage = data['profileImage'].toString();
          } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
            displayImage = data['imageUrl'].toString();
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // -- PROFILE IMAGE --
                      Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 4),
                            boxShadow: [
                              BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.1))
                            ]
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                          backgroundImage: displayImage.isNotEmpty
                              ? CachedNetworkImageProvider(displayImage) // Optimized
                              : null,
                          child: displayImage.isEmpty
                              ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                              : null,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // -- NAME & SPECIALTY --
                      Text(
                        "Dr. $name",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialization,
                        style: TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 24),

                      // -- STATS ROW --
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem("Experience", "$experience Yrs", Colors.blue, statBgColor, textColor),

                          // --- DYNAMIC PATIENT COUNT ---
                          FutureBuilder<AggregateQuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('appointments')
                                .where('doctorId', isEqualTo: doctorId)
                                .count()
                                .get(),
                            builder: (context, countSnapshot) {
                              String patientCount = "...";
                              if (countSnapshot.hasData) {
                                patientCount = "${countSnapshot.data!.count}+";
                              }
                              return _buildStatItem("Patients", patientCount, Colors.orange, statBgColor, textColor);
                            },
                          ),

                          _buildStatItem("Rating", rating, Colors.amber, statBgColor, textColor),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // -- EXTRA INFO SCROLL --
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatItem("Phone", phone, Colors.green, statBgColor, textColor),
                            const SizedBox(width: 10),
                            _buildStatItem("PMDC", pmdcNumber, Colors.purple, statBgColor, textColor),
                            const SizedBox(width: 10),
                            _buildStatItem("Start", startTiming, Colors.redAccent, statBgColor, textColor),
                            const SizedBox(width: 10),
                            _buildStatItem("End", endTiming, Colors.pinkAccent, statBgColor, textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // -- ABOUT SECTION --
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "About Doctor",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, spreadRadius: 1)
                            ]
                        ),
                        child: Text(
                          bio,
                          style: TextStyle(fontSize: 15, color: subTextColor, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // -- BOTTOM ACTIONS (Chat + Book) --
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                  ],
                ),
                child: Row(
                  children: [
                    // 1. CHAT BUTTON
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: () => _startChat(context, doctorId, name),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Chat"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            side: const BorderSide(color: Colors.blueAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),

                    // 2. BOOK BUTTON
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                                context,
                                '/book_appointment',
                                arguments: {
                                  'doctorId': doctorId,
                                  'doctorName': name,
                                  'start_timing': startTiming,
                                  'end_timing': endTiming,
                                  'fees': data['fees'] ?? '1500', // Pass fees too if needed
                                }
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Book Now",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color iconColor, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}