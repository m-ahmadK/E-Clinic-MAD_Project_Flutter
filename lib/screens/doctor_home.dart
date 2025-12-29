import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'doctor_profile_screen.dart';
import 'doctor_prescription_screen.dart';
import 'doctor_chat_list_screen.dart'; // IMPORT THE NEW SCREEN

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _selectedIndex = 0;
  bool _isOnline = true;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isOnline = value);
    await FirebaseFirestore.instance.collection('users').doc(_uid).update({
      'isAvailable': value,
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _formatAppointmentTime(String rawTime) {
    if (rawTime == 'TBD' || rawTime.isEmpty) return rawTime;
    try {
      List<String> parts = rawTime.trim().split(' ');
      if (parts.length < 2) return rawTime;
      List<String> timeParts = parts[0].split(':');
      if (timeParts.length < 2) return rawTime;
      String hour = timeParts[0].padLeft(2, '0');
      String minute = timeParts[1].padLeft(2, '0');
      String period = parts[1];
      return "$hour:$minute $period";
    } catch (e) {
      return rawTime;
    }
  }

  void _showCancellationDialog(BuildContext context, String docId, String patientId, Color textColor, Color cardColor) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text("Cancel Appointment", style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Please provide a reason for cancellation:", style: TextStyle(color: textColor.withOpacity(0.7))),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: "E.g. Emergency surgery, Patient no-show...",
                  hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: textColor.withOpacity(0.05),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reason is required.")));
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('appointmentResults').add({
                    'appointmentId': docId,
                    'patientId': patientId,
                    'doctorId': _uid,
                    'type': 'cancellation',
                    'reason': reasonController.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
                    'status': 'cancelled',
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment Cancelled")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Confirm Cancel", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[100];
    final navColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // --- UPDATED PAGES LIST ---
    final List<Widget> pages = [
      _buildDashboard(isDark),
      const DoctorChatListScreen(), // NEW CHAT SCREEN
      const DoctorProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: navColor,
        indicatorColor: Colors.blueAccent.withOpacity(0.2),
        elevation: 10,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: isDark ? Colors.white70 : Colors.black54),
            selectedIcon: const Icon(Icons.dashboard, color: Colors.blueAccent),
            label: 'Home',
          ),
          // --- NEW CHAT ITEM ---
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, color: isDark ? Colors.white70 : Colors.black54),
            selectedIcon: const Icon(Icons.chat_bubble, color: Colors.blueAccent),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: isDark ? Colors.white70 : Colors.black54),
            selectedIcon: const Icon(Icons.person, color: Colors.blueAccent),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final Stream<QuerySnapshot> appointmentStream = FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: _uid)
        .snapshots();

    final Stream<DocumentSnapshot> userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          StreamBuilder<DocumentSnapshot>(
              stream: userStream,
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox();

                var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                String doctorName = userData?['name'] ?? "Doctor";
                String? profileImageUrl = userData?['profileImage'];

                return Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                      child: profileImageUrl == null || profileImageUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.blueAccent)
                          : null,
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: subTextColor, fontSize: 16)),
                        Text('Dr. $doctorName', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  ],
                );
              }
          ),

          const SizedBox(height: 25),

          // AVAILABILITY CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.blueAccent : (isDark ? Colors.grey[800] : Colors.grey),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Availability Status', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 5),
                    Text(_isOnline ? 'You are Online' : 'You are Offline', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Switch(
                  value: _isOnline,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.lightGreenAccent,
                  onChanged: _toggleAvailability,
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // APPOINTMENTS LIST
          StreamBuilder<QuerySnapshot>(
            stream: appointmentStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final total = docs.length;
              final pending = docs.where((doc) => doc['status'] == 'pending').length;
              final completed = docs.where((doc) => doc['status'] == 'completed').length;
              final pendingAppointments = docs.where((doc) => doc['status'] == 'pending').toList();

              return Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard('Pending', '$pending', Colors.orange, cardColor, textColor, subTextColor),
                      const SizedBox(width: 15),
                      _buildStatCard('Completed', '$completed', Colors.green, cardColor, textColor, subTextColor),
                      const SizedBox(width: 15),
                      _buildStatCard('Total', '$total', Colors.purple, cardColor, textColor, subTextColor),
                    ],
                  ),
                  const SizedBox(height: 30),

                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Pending Requests", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))
                  ),
                  const SizedBox(height: 15),

                  pendingAppointments.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No new appointments", style: TextStyle(color: subTextColor))))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingAppointments.length,
                    itemBuilder: (context, index) {
                      final data = pendingAppointments[index].data() as Map<String, dynamic>;
                      final docId = pendingAppointments[index].id;
                      return _buildAppointmentCard(data, docId, cardColor, textColor, subTextColor);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, Color cardColor, Color textColor, Color subTextColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(color: subTextColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data, String docId, Color cardColor, Color textColor, Color subTextColor) {
    String name = data['patientName'] ?? 'Unknown';
    String time = data['time'] ?? 'TBD';
    String issue = data['reason'] ?? 'No symptoms provided';
    String patientId = data['patientId'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatAppointmentTime(time),
              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                const SizedBox(height: 4),
                Text(issue, style: TextStyle(color: subTextColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DoctorPrescriptionScreen(
                        appointmentId: docId,
                        patientId: patientId,
                        doctorId: _uid,
                        patientName: name,
                        symptoms: issue,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _showCancellationDialog(context, docId, patientId, textColor, cardColor),
              ),
            ],
          )
        ],
      ),
    );
  }
}