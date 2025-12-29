import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart'; // Make sure this path matches your project structure
import 'patient_history_screen.dart'; // IMPORT THE HISTORY SCREEN

class DoctorPrescriptionScreen extends StatefulWidget {
  final String appointmentId;
  final String patientId; // Added for the new collection
  final String doctorId;  // Added for the new collection
  final String patientName;
  final String symptoms;

  const DoctorPrescriptionScreen({
    super.key,
    required this.appointmentId,
    required this.patientId, // Required
    required this.doctorId,  // Required
    required this.patientName,
    required this.symptoms,
  });

  @override
  State<DoctorPrescriptionScreen> createState() => _DoctorPrescriptionScreenState();
}

class _DoctorPrescriptionScreenState extends State<DoctorPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _prescriptionController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitPrescription() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. Create a NEW document in 'appointmentResults' collection
      await FirebaseFirestore.instance.collection('appointmentResults').add({
        'appointmentId': widget.appointmentId,
        'patientId': widget.patientId,
        'doctorId': widget.doctorId,
        'type': 'prescription', // To distinguish from cancellations
        'diagnosis': _diagnosisController.text.trim(),
        'prescription': _prescriptionController.text.trim(),
        'symptoms': widget.symptoms,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update the Appointment Status to 'completed'
      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
        'status': 'completed',
      });

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription Sent & Saved!')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. LISTEN TO THEME
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // 2. DEFINE DYNAMIC COLORS
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50]!;
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color inputFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Patient Diagnosis", style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PATIENT DETAILS CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, "Patient Name", widget.patientName, textColor, subTextColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                    ),
                    _buildInfoRow(Icons.sick_outlined, "Reported Symptoms", widget.symptoms, textColor, subTextColor),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- HISTORY TILE (Now Functional) ---
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                tileColor: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.history, color: Colors.orange),
                ),
                title: Text("View Patient History", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor),
                // 👇 THIS IS THE KEY CHANGE
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientHistoryScreen(
                        patientId: widget.patientId, // Pass the patient ID so Doctor sees THEIR history
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
              Text("Diagnosis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),

              // --- DIAGNOSIS INPUT ---
              TextFormField(
                controller: _diagnosisController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: "E.g. Viral Flu",
                  hintStyle: TextStyle(color: subTextColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) => v!.isEmpty ? "Diagnosis is required" : null,
              ),

              const SizedBox(height: 20),
              Text("Prescription & Advice", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),

              // --- PRESCRIPTION INPUT ---
              TextFormField(
                controller: _prescriptionController,
                maxLines: 5,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: "Enter medicines, dosage, and advice...",
                  hintStyle: TextStyle(color: subTextColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (v) => v!.isEmpty ? "Prescription is required" : null,
              ),

              const SizedBox(height: 40),

              // --- CONFIRM BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPrescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                    shadowColor: Colors.blueAccent.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Confirm Prescription", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value, Color textColor, Color subTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: subTextColor, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
        ),
      ],
    );
  }
}