import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TotalAppointmentsScreen extends StatefulWidget {
  const TotalAppointmentsScreen({super.key});

  @override
  State<TotalAppointmentsScreen> createState() =>
      _TotalAppointmentsScreenState();
}

class _TotalAppointmentsScreenState extends State<TotalAppointmentsScreen> {
  // --- DELETE APPOINTMENT ---
  Future<void> _deleteAppointment(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Appointment?"),
        content: const Text(
            "Are you sure you want to delete this appointment record?\nThis cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
            const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment record deleted")));
    }
  }

  // --- ADD APPOINTMENT DIALOG ---
  void _showAddAppointmentDialog() {
    final _formKey = GlobalKey<FormState>();
    final docNameCtrl = TextEditingController();
    final docIdCtrl = TextEditingController();
    final patNameCtrl = TextEditingController();
    final patIdCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    String selectedStatus = 'Pending';
    final List<String> statusOptions = [
      'Pending',
      'Confirmed',
      'Completed',
      'Cancelled'
    ];

    bool isLoading = false;

    // Helper to pick Date
    Future<void> pickDate(BuildContext context) async {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        const months = [
          "Jan", "Feb", "Mar", "Apr", "May", "Jun",
          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        String formatted =
            "${months[picked.month - 1]} ${picked.day}, ${picked.year}";
        dateCtrl.text = formatted;
      }
    }

    // Helper to pick Time
    Future<void> pickTime(BuildContext context) async {
      TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        final localizations = MaterialLocalizations.of(context);
        String formattedTime =
        localizations.formatTimeOfDay(picked, alwaysUse24HourFormat: false);
        timeCtrl.text = formattedTime;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Book Appointment"),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // DOCTOR
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Doctor",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue))),
                    Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: TextFormField(
                                controller: docNameCtrl,
                                decoration:
                                const InputDecoration(labelText: "Name"),
                                validator: (v) =>
                                v!.isEmpty ? "Required" : null)),
                        const SizedBox(width: 10),
                        Expanded(
                            flex: 1,
                            child: TextFormField(
                                controller: docIdCtrl,
                                decoration:
                                const InputDecoration(labelText: "ID"))),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // PATIENT
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Patient",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue))),
                    Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: TextFormField(
                                controller: patNameCtrl,
                                decoration:
                                const InputDecoration(labelText: "Name"),
                                validator: (v) =>
                                v!.isEmpty ? "Required" : null)),
                        const SizedBox(width: 10),
                        Expanded(
                            flex: 1,
                            child: TextFormField(
                                controller: patIdCtrl,
                                decoration:
                                const InputDecoration(labelText: "ID"))),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // DATE & TIME
                    TextFormField(
                      controller: dateCtrl,
                      readOnly: true,
                      onTap: () => pickDate(context),
                      decoration: const InputDecoration(
                          labelText: "Date",
                          hintText: "Select Date",
                          suffixIcon: Icon(Icons.calendar_month, size: 20)),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: timeCtrl,
                      readOnly: true,
                      onTap: () => pickTime(context),
                      decoration: const InputDecoration(
                          labelText: "Time",
                          hintText: "Select Time",
                          suffixIcon: Icon(Icons.access_time, size: 20)),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: "Status"),
                      items: statusOptions.map((String status) {
                        return DropdownMenuItem(
                            value: status, child: Text(status));
                      }).toList(),
                      onChanged: (val) => setState(() => selectedStatus = val!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => isLoading = true);

                  try {
                    await FirebaseFirestore.instance
                        .collection('appointments')
                        .add({
                      'doctorName': docNameCtrl.text.trim(),
                      'doctorId': docIdCtrl.text.trim(),
                      'doctorImage': "",
                      'patientName': patNameCtrl.text.trim(),
                      'patientId': patIdCtrl.text.trim(),
                      'date': dateCtrl.text.trim(),
                      'time': timeCtrl.text.trim(),
                      'status': selectedStatus,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Appointment Created!")));
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C97FA)),
                child: isLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white))
                    : const Text("Book Now",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // --- HELPER FOR STATUS COLORS ---
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // --- HELPER TO FIX THE TIMESTAMP ISSUE ---
  String _formatDateString(dynamic dateData) {
    if (dateData == null) return "--/--";

    // Check if it's a Firestore Timestamp (which caused your bug)
    if (dateData is Timestamp) {
      DateTime date = dateData.toDate();
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    }

    // Check if it's already a String
    return dateData.toString();
  }

  // --- HELPER TO FORMAT TIME ---
  String _formatTimeString(dynamic timeData) {
    if(timeData == null) return "--:--";
    return timeData.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("All Appointments",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2C97FA),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAppointmentDialog,
        backgroundColor: const Color(0xFF2C97FA),
        elevation: 4,
        icon: const Icon(Icons.calendar_month, color: Colors.white),
        label: const Text("New Booking", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey),
                  SizedBox(height: 15),
                  Text("No appointments scheduled",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // --- ROBUST PARSING ---
              String doctorName = (data['doctorName'] ?? "Unknown").toString();
              String doctorImage = (data['profileImage'] ??
                  data['imageUrl'] ??
                  data['photoUrl'] ??
                  "")
                  .toString();
              String patientName = (data['patientName'] ?? "Unknown").toString();
              String patientId = (data['patientId'] ?? "").toString();
              String status = (data['status'] ?? "Pending").toString();

              // Use the helper functions to fix the weird text
              String date = _formatDateString(data['date']);
              String time = _formatTimeString(data['time']);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade50,
                          border:
                          Border.all(color: Colors.blue.shade100, width: 1),
                        ),
                        child: ClipOval(
                          child: (doctorImage.isNotEmpty)
                              ? Image.network(
                            doctorImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  doctorName.isNotEmpty
                                      ? doctorName[0].toUpperCase()
                                      : "D",
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C97FA)),
                                ),
                              );
                            },
                          )
                              : Center(
                            child: Text(
                              doctorName.isNotEmpty
                                  ? doctorName[0].toUpperCase()
                                  : "D",
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C97FA)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // --- 2. DETAILS CENTER ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Doctor Name Row
                            Row(
                              children: [
                                const Icon(Icons.medical_services,
                                    size: 14, color: Color(0xFF2C97FA)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    doctorName,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            //

                            Row(
                              children: [
                                const Icon(Icons.person,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    patientName,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),
                            Divider(height: 1, color: Colors.grey.shade100),
                            const SizedBox(height: 10),

                            // --- DATE & TIME COLUMN (Fixed Layout) ---
                            // 1. Date Row
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  date,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // 2. Time Row (Below Date)
                            Row(
                              children: [
                                Icon(Icons.access_time_filled,
                                    size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  time,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // --- 3. STATUS & ACTION (Right Side) ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          IconButton(
                            onPressed: () => _deleteAppointment(doc.id),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}