import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({super.key});

  // --- HELPER: Fix Time Format (01:00 PM) ---
  String _formatTime(String rawTime) {
    if (rawTime.isEmpty || rawTime == "--:--") return rawTime;
    try {
      String cleaned = rawTime.replaceAll('.', ':').trim();
      var parts = cleaned.split(' ');
      String timePart = parts[0];
      String period = parts.length > 1 ? parts[1].toUpperCase() : "";

      var timeSplit = timePart.split(':');
      int hour = int.parse(timeSplit[0]);
      int minute = timeSplit.length > 1 ? int.parse(timeSplit[1]) : 0;

      if (period.isEmpty) {
        if (hour >= 12) {
          period = "PM";
          if (hour > 12) hour -= 12;
        } else {
          period = "AM";
          if (hour == 0) hour = 12;
        }
      }

      String hStr = hour.toString().padLeft(2, '0');
      String mStr = minute.toString().padLeft(2, '0');

      return "$hStr:$mStr $period";
    } catch (e) {
      return rawTime;
    }
  }

  // --- HELPER: Start Chat ---
  void _startChat(BuildContext context, String doctorId, String doctorName, String patientId) {
    Navigator.pushNamed(context, '/chat_screen', arguments: {
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'isPatientView': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final Map<String, dynamic> data = args['data'];
    final String appointmentId = args['appointmentId'];

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final headerColor = Colors.blueAccent;
    final bgColor = headerColor;
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF222B45);
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Data from Appointment Document
    final String doctorName = data['doctorName'] ?? "Doctor";
    final String doctorId = data['doctorId'] ?? "";
    final String patientId = data['patientId'] ?? "";
    final String patientName = data['patientName'] ?? "Patient";
    final String status = data['status'] ?? "pending";
    final String reason = data['reason'] ?? "N/A";

    // Fix Time
    final String time = _formatTime(data['time'] ?? "--:--");

    // Date Logic
    String dateStr = "Unknown Date";
    if (data['date'] is Timestamp) {
      DateTime dt = (data['date'] as Timestamp).toDate();
      dateStr = "${dt.day} ${_getMonth(dt.month)}, ${dt.year}";
    } else if (data['dateStr'] != null) {
      dateStr = data['dateStr'];
    }

    bool canRate = (status == 'completed' || status == 'cancelled');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Appointment Details", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: headerColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
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
              // FETCH DOCTOR DATA
              child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
                  builder: (context, snapshot) {
                    // Default Values
                    String doctorImage = "";
                    String specialization = "Specialist";
                    String fee = "N/A";

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final docData = snapshot.data!.data() as Map<String, dynamic>;
                      doctorImage = docData['profileImage'] ?? docData['imageUrl'] ?? "";
                      specialization = docData['specialization'] ?? "Specialist";

                      // --- FIX IS HERE: ADD .toString() ---
                      // This handles if 'fees' is Int or String in Firestore
                      fee = (docData['fees'] ?? "N/A").toString();
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // 1. DOCTOR CARD
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
                              ],
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                  backgroundImage: doctorImage.isNotEmpty
                                      ? CachedNetworkImageProvider(doctorImage)
                                      : null,
                                  child: doctorImage.isEmpty
                                      ? const Icon(Icons.person, color: Colors.blueAccent, size: 30)
                                      : null,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Dr. $doctorName",
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        specialization,
                                        style: const TextStyle(color: Colors.blueAccent, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                // CHAT BUTTON
                                GestureDetector(
                                  onTap: () => _startChat(context, doctorId, doctorName, patientId),
                                  child: const CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.blueAccent,
                                    child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // 2. DETAILS GRID
                          Row(
                            children: [
                              Expanded(child: _buildLabelValue("Full Name", patientName, labelColor, textColor)),
                              Expanded(child: _buildLabelValue("Age", "24", labelColor, textColor)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _buildLabelValue("Gender", "Male", labelColor, textColor)),
                              Expanded(child: _buildLabelValue("Problem", reason, labelColor, textColor)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _buildLabelValue("Date", dateStr, labelColor, textColor)),
                              Expanded(child: _buildLabelValue("Time", time, labelColor, textColor)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _buildLabelValue("Status", status.toUpperCase(), labelColor, _getStatusColor(status))),
                              Expanded(child: _buildLabelValue("Fee", "$fee PKR", labelColor, textColor)),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // 3. RATING BUTTON
                          if (canRate)
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => RatingDialog(
                                      doctorId: doctorId,
                                      doctorName: doctorName,
                                      patientId: patientId,
                                      appointmentId: appointmentId,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  "Rate Appointment",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),

                          if (!canRate)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text("Appointment is $status", style: TextStyle(color: labelColor)),
                              ),
                            ),
                        ],
                      ),
                    );
                  }
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value, Color? labelColor, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'completed': return Colors.blue;
      default: return Colors.orange;
    }
  }

  String _getMonth(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }
}

// --- RATING DIALOG WIDGET ---
class RatingDialog extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String appointmentId;

  const RatingDialog({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.appointmentId,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a star rating.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('ratings').add({
        'doctorId': widget.doctorId,
        'patientId': widget.patientId,
        'appointmentId': widget.appointmentId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rating Submitted!")));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Rate Your Experience", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 5),
          Text("How was your appointment with?", style: TextStyle(color: Colors.grey[500], fontSize: 12)),

          const SizedBox(height: 15),
          Text("Dr. ${widget.doctorName}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 20),

          // --- STAR RATING ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text("$_rating / 5", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),

          const SizedBox(height: 20),

          TextField(
            controller: _commentController,
            maxLines: 3,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Write a review (optional)...",
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Submit Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}