import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:intl/intl.dart'; // Ensure you have intl: ^0.18.0 in pubspec.yaml

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
  late String _targetUid;
  late bool _isDoctorView;
  int _currentTab = 0; // 0 = Visits History, 1 = Medical Profile

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (widget.patientId != null) {
      _targetUid = widget.patientId!;
      _isDoctorView = true;
    } else {
      _targetUid = currentUser!.uid;
      _isDoctorView = false;
    }

    _loadStaticHistory();
  }

  // 1. Load Static History
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

  // 2. Save History
  Future<void> _saveHistory() async {
    if (_isDoctorView) return;
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

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medical Profile Updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- THEME & COLORS ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final headerColor = Colors.blueAccent;
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF222B45);
    final subTextColor = isDark ? Colors.grey[400] : const Color(0xFF6B779A);
    final inputFill = isDark ? const Color(0xFF2C2C2C) : Colors.grey[50]!;

    return Scaffold(
      backgroundColor: headerColor, // Blue Top
      appBar: AppBar(
        title: Text(_isDoctorView ? "Patient History" : "Medical History", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: headerColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // --- MAIN CONTAINER ---
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
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // --- TOGGLE TABS (Visits vs Profile) ---
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton("Visits History", 0, isDark),
                        _buildTabButton("Medical Profile", 1, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // --- CONTENT AREA ---
                  Expanded(
                    child: _currentTab == 0
                        ? _buildVisitsList(textColor, subTextColor, inputFill)
                        : _buildProfileForm(textColor, subTextColor, inputFill),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB BUTTON ---
  Widget _buildTabButton(String title, int index, bool isDark) {
    bool isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isActive ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : (isDark ? Colors.grey : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 1: VISITS HISTORY (Stream) ---
  Widget _buildVisitsList(Color textColor, Color? subTextColor, Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointmentResults')
          .where('patientId', isEqualTo: _targetUid)
          .where('type', isEqualTo: 'prescription')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // If index error occurs, show hint
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("Waiting for Index... (Check Console if stuck)", style: TextStyle(color: subTextColor)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("No medical records found.", style: TextStyle(color: subTextColor)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          itemCount: docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 15),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildHistoryCard(data, cardColor, textColor, subTextColor!);
          },
        );
      },
    );
  }

  // --- TAB 2: PROFILE FORM ---
  Widget _buildProfileForm(Color textColor, Color? subTextColor, Color inputFill) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update your medical info for better diagnosis.", style: TextStyle(color: subTextColor, fontSize: 13)),
            const SizedBox(height: 20),

            _buildTextField("Chronic Conditions", _conditionsController, Icons.favorite, inputFill, textColor, subTextColor!),
            const SizedBox(height: 15),
            _buildTextField("Past Surgeries", _surgeriesController, Icons.medical_services, inputFill, textColor, subTextColor),
            const SizedBox(height: 15),
            _buildTextField("Current Medications", _medicationsController, Icons.medication, inputFill, textColor, subTextColor),
            const SizedBox(height: 15),
            _buildTextField("Allergies", _allergiesController, Icons.warning, inputFill, textColor, subTextColor),

            const SizedBox(height: 30),

            if (!_isDoctorView)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 4,
                  ),
                  child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, Color fillColor, Color textColor, Color hintColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: _isDoctorView,
            style: TextStyle(color: textColor),
            maxLines: null,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              hintText: _isDoctorView ? "None" : "Type here...",
              hintStyle: TextStyle(color: hintColor.withOpacity(0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data, Color cardColor, Color textColor, Color subTextColor) {
    String diagnosis = data['diagnosis'] ?? "Unknown";
    String prescription = data['prescription'] ?? "No medicines";

    // Format Date (Requires intl package)
    String dateStr = "Unknown Date";
    if (data['timestamp'] != null) {
      DateTime dt = (data['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat('MMM d, yyyy').format(dt); // e.g., Dec 25, 2025
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor, // Adapts to theme
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  diagnosis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.withOpacity(0.1)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.medication_liquid, size: 16, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prescription,
                  style: TextStyle(color: subTextColor, fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}