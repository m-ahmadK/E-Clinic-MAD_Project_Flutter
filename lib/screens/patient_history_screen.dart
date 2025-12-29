import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
// import 'package:intl/intl.dart'; // UNCOMMENT if you want formatted dates (e.g., Dec 25, 2025)

class PatientHistoryScreen extends StatefulWidget {
  final String? patientId; // If null, it assumes the current user (Patient View)

  const PatientHistoryScreen({super.key, this.patientId});

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _surgeriesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();

  bool _isLoading = false;
  late String _targetUid; // The ID of the patient we are viewing
  late bool _isDoctorView; // To check if we should allow editing

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;

    // DECIDE MODE:
    // If patientId is passed, a Doctor is viewing a specific patient.
    // If patientId is null, the Patient is viewing their own profile.
    if (widget.patientId != null) {
      _targetUid = widget.patientId!;
      _isDoctorView = true;
    } else {
      _targetUid = currentUser!.uid;
      _isDoctorView = false;
    }

    _loadStaticHistory();
  }

  // 1. Load Static History (Conditions, Allergies)
  Future<void> _loadStaticHistory() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('patient_history').doc(_targetUid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _conditionsController.text = data['conditions'] ?? '';
        _surgeriesController.text = data['surgeries'] ?? '';
        _medicationsController.text = data['medications'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Save History (Only for Patient)
  Future<void> _saveHistory() async {
    if (_isDoctorView) return; // Doctors cannot edit this part
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('patient_history').doc(_targetUid).set({
        'patientId': _targetUid,
        'conditions': _conditionsController.text.trim(),
        'surgeries': _surgeriesController.text.trim(),
        'medications': _medicationsController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medical Profile Updated!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // THEME SETUP
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.blue;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.black;
    final inputFill = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isDoctorView ? "Patient Medical Record" : "My Medical History", style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- SECTION 1: STATIC PROFILE (Conditions, Allergies) ---
            Text("General Medical Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 15),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField("Chronic Conditions", _conditionsController, Icons.favorite, isDark, inputFill, textColor, subTextColor!),
                  const SizedBox(height: 15),
                  _buildTextField("Past Surgeries", _surgeriesController, Icons.medical_services, isDark, inputFill, textColor, subTextColor),
                  const SizedBox(height: 15),
                  _buildTextField("Current Medications", _medicationsController, Icons.medication, isDark, inputFill, textColor, subTextColor),
                  const SizedBox(height: 15),
                  _buildTextField("Allergies", _allergiesController, Icons.warning, isDark, inputFill, textColor, subTextColor),
                ],
              ),
            ),

            // Save Button (Only for Patient)
            if (!_isDoctorView) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveHistory,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text("Update Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            const SizedBox(height: 35),
            const Divider(),
            const SizedBox(height: 15),

            // --- SECTION 2: PAST APPOINTMENT RESULTS (Fetched from Database) ---
            Text("Clinical History (Past Visits)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointmentResults')
                  .where('patientId', isEqualTo: _targetUid)
                  .where('type', isEqualTo: 'prescription')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Center(child: Text("No past medical records found.", style: TextStyle(color: subTextColor))),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildHistoryCard(data, cardColor, textColor, subTextColor);
                  },
                );
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Text Field (Editable or Read-Only based on mode) ---
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isDark, Color fillColor, Color textColor, Color hintColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: hintColor)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: _isDoctorView, // Doctor can't edit
            style: TextStyle(color: textColor),
            maxLines: null, // Auto-expand
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              hintText: _isDoctorView ? "Not recorded" : "Tap to add info...",
              hintStyle: TextStyle(color: hintColor.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET: Past Appointment Card ---
  Widget _buildHistoryCard(Map<String, dynamic> data, Color cardColor, Color textColor, Color subTextColor) {
    String diagnosis = data['diagnosis'] ?? "Unknown";
    String prescription = data['prescription'] ?? "No medicines";
    // Timestamp timestamp = data['timestamp']; // You can format this if you uncomment intl package

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.assignment_turned_in, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  diagnosis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                ),
              ),
              // Optional: Display Date here
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 5),
          Text("Prescription:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
          const SizedBox(height: 4),
          Text(
            prescription,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}