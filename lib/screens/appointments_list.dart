import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppointmentsList extends StatelessWidget {
  const AppointmentsList({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please login first"));

    return Column(
      children: [
        // --- HEADER ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 20, top: 55),
          decoration: const BoxDecoration(
            color: Colors.blue,
            boxShadow: [
              BoxShadow(
                color: Colors.blue,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            "My Appointments",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),

        // --- LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientId', isEqualTo: user.uid)
            // Note: Ensure Firestore Index is created for 'createdAt' descending
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final String docId = docs[index].id; // Get the Appointment ID

                  return _buildAppointmentCard(context, data, docId);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No appointments yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, Map<String, dynamic> data, String appointmentId) {
    final String doctorName = data['doctorName'] ?? "Unknown Doctor";
    final String dateStr = _formatTimestamp(data['date']);
    final String time = data['time'] ?? "--:--";
    final String status = data['status'] ?? "pending";
    final String reason = data['reason'] ?? "No reason provided";

    Color statusColor;
    bool isActionable = false; // To check if we should show the button

    switch (status.toLowerCase()) {
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'cancelled': // Matches your database string
        statusColor = Colors.red;
        isActionable = true; // Can view reason
        break;
      case 'completed':
        statusColor = Colors.blue;
        isActionable = true; // Can view prescription
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Doctor Name & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text("Dr. $doctorName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),

            // Middle Row: Date & Time
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 20),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(time, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),

            // Bottom Section: Symptom Reason
            Text("Symptoms: $reason", style: const TextStyle(color: Colors.black54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),

            // --- THE NEW BUTTON LOGIC ---
            if (isActionable) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _fetchAndShowResult(context, appointmentId, status),
                  icon: Icon(
                    status.toLowerCase() == 'completed' ? Icons.description : Icons.info_outline,
                    size: 18,
                    color: statusColor,
                  ),
                  label: Text(
                    status.toLowerCase() == 'completed' ? "View Prescription" : "View Cancellation Reason",
                    style: TextStyle(color: statusColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: statusColor.withOpacity(0.5)),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  // --- LOGIC TO FETCH RESULT FROM 'appointmentResults' ---
  Future<void> _fetchAndShowResult(BuildContext context, String appointmentId, String status) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Query the 'appointmentResults' collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointmentResults')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      if (querySnapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Details not found.")));
        }
        return;
      }

      final resultData = querySnapshot.docs.first.data();

      // Show the details dialog
      if (context.mounted) {
        _showResultDialog(context, resultData, status);
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching details: $e")));
      }
    }
  }

  // --- THE UI FOR THE POPUP DIALOG ---
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
                  // --- SHOW PRESCRIPTION ---
                  _buildDetailTitle("Medical Diagnosis:"),
                  Text(data['diagnosis'] ?? "N/A", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 15),
                  _buildDetailTitle("Prescription & Advice:"),
                  Text(data['prescription'] ?? "N/A", style: const TextStyle(fontSize: 16)),
                ] else ...[
                  // --- SHOW CANCELLATION REASON ---
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Unknown Date";
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return "${date.day}/${date.month}/${date.year}";
      }
      return timestamp.toString();
    } catch (e) {
      return "Invalid Date";
    }
  }
}