import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppointmentsList extends StatelessWidget {
  const AppointmentsList({super.key});

  // --- HELPER: Fix Time Format (e.g. "4:0 PM" -> "04:00 PM") ---
  String _formatTime(String rawTime) {
    if (rawTime.isEmpty) return "--:--";
    try {
      // 1. Handle "4.0pm" case if it exists, replace . with :
      String cleaned = rawTime.replaceAll('.', ':').trim();

      // 2. Split into Time and Period
      var parts = cleaned.split(' ');
      if (parts.length < 2) return cleaned; // Return original if parsing fails

      var timeParts = parts[0].split(':');
      if (timeParts.length < 2) return cleaned;

      String hour = timeParts[0].padLeft(2, '0');
      String minute = timeParts[1].padLeft(2, '0'); // Ensures "4:0" becomes "4:00"
      String period = parts[1].toUpperCase();

      return "$hour:$minute $period";
    } catch (e) {
      return rawTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final headerColor = Colors.blueAccent;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F9FF);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF222B45);
    final subTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6B779A);

    if (user == null) return const Center(child: Text("Please login first"));

    return Scaffold(
      backgroundColor: headerColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- 1. HEADER (No Back Button) ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Center(
                child: Text(
                  "My Appointments",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // --- 2. LIST CONTAINER ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('patientId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(subTextColor);
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final docId = docs[index].id;

                        return _buildAppointmentCard(
                            context, data, docId, cardColor, textColor, subTextColor
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No appointments yet.", style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
      BuildContext context,
      Map<String, dynamic> appointmentData,
      String appointmentId,
      Color cardColor,
      Color textColor,
      Color subTextColor
      ) {

    // Basic Data from Appointment Doc
    final String doctorId = appointmentData['doctorId'] ?? "";
    final String rawTime = appointmentData['time'] ?? "--:--";
    final String status = appointmentData['status'] ?? "pending";

    // Format Time
    final String time = _formatTime(rawTime);

    // Status Logic
    Color statusBgColor;
    Color statusTextColor;
    String statusText = status;

    switch (status.toLowerCase()) {
      case 'confirmed':
        statusBgColor = const Color(0xFFE8F5E9);
        statusTextColor = Colors.green;
        break;
      case 'cancelled':
        statusBgColor = const Color(0xFFFFEBEE);
        statusTextColor = Colors.red;
        break;
      case 'completed':
        statusBgColor = const Color(0xFFE3F2FD);
        statusTextColor = Colors.blue;
        break;
      default:
        statusBgColor = const Color(0xFFFFF3E0);
        statusTextColor = Colors.orange;
    }

    bool isActionable = (status == 'completed' || status == 'cancelled');

    // --- FETCH DOCTOR DETAILS (Image & Specialization) ---
    return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
        builder: (context, snapshot) {
          // Default values while loading or if fails
          String doctorName = appointmentData['doctorName'] ?? "Doctor";
          String specialization = "Specialist";
          String? doctorImage;

          if (snapshot.hasData && snapshot.data!.exists) {
            final docData = snapshot.data!.data() as Map<String, dynamic>;
            // Prefer name from User doc as it might be updated
            doctorName = docData['name'] ?? doctorName;
            specialization = docData['specialization'] ?? "Specialist";
            // Get Image URL
            if (docData['profileImage'] != null && docData['profileImage'].toString().isNotEmpty) {
              doctorImage = docData['profileImage'];
            } else if (docData['imageUrl'] != null && docData['imageUrl'].toString().isNotEmpty) {
              doctorImage = docData['imageUrl'];
            }
          }

          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                  context,
                  '/appointment_detail',
                  arguments: {
                    'appointmentId': appointmentId,
                    'data': appointmentData,
                  }
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // -- DOCTOR IMAGE (Fetched) --
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.1), width: 1),
                        ),
                        child: ClipOval(
                          child: doctorImage != null
                              ? CachedNetworkImage(
                            imageUrl: doctorImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Padding(
                              padding: EdgeInsets.all(15.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.blue),
                          )
                              : const Icon(Icons.person, color: Colors.blue, size: 30),
                        ),
                      ),

                      const SizedBox(width: 15),

                      // -- INFO (Name & Specialization) --
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Dr. $doctorName",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Specialization (New)
                            Text(
                              specialization,
                              style: TextStyle(fontSize: 12, color: subTextColor),
                            ),
                            const SizedBox(height: 6),
                            // Formatted Time
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: Colors.blueAccent.withOpacity(0.7)),
                                const SizedBox(width: 5),
                                Text(
                                  time,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // -- STATUS PILL --
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText.isNotEmpty
                                  ? "${statusText[0].toUpperCase()}${statusText.substring(1)}"
                                  : statusText,
                              style: TextStyle(
                                color: statusTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // -- ACTION LINKS --
                  if (isActionable) ...[
                    const SizedBox(height: 15),
                    Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () => _fetchAndShowResult(context, appointmentId, status),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            status == 'completed' ? Icons.receipt_long : Icons.info_outline,
                            size: 16,
                            color: statusTextColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status == 'completed' ? "View Prescription" : "View Cancellation Reason",
                            style: TextStyle(
                              color: statusTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
          );
        }
    );
  }

  // --- LOGIC: FETCH RESULT ---
  Future<void> _fetchAndShowResult(BuildContext context, String appointmentId, String status) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointmentResults')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (context.mounted) Navigator.pop(context);

      if (querySnapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Details not found.")));
        }
        return;
      }

      final resultData = querySnapshot.docs.first.data();

      if (context.mounted) {
        _showResultDialog(context, resultData, status);
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching details: $e")));
      }
    }
  }

  void _showResultDialog(BuildContext context, Map<String, dynamic> data, String status) {
    bool isCompleted = status.toLowerCase() == 'completed';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(isCompleted ? Icons.medical_services : Icons.cancel, color: isCompleted ? Colors.blue : Colors.red),
              const SizedBox(width: 10),
              Text(isCompleted ? "Prescription" : "Cancellation"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted) ...[
                  _buildDetailTitle("Medical Diagnosis:"),
                  Text(data['diagnosis'] ?? "N/A", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 15),
                  _buildDetailTitle("Prescription & Advice:"),
                  Text(data['prescription'] ?? "N/A", style: const TextStyle(fontSize: 16)),
                ] else ...[
                  _buildDetailTitle("Reason for Cancellation:"),
                  Text(data['reason'] ?? "No reason provided.", style: const TextStyle(fontSize: 16, color: Colors.redAccent)),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
      ),
    );
  }
}