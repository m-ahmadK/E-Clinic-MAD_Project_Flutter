import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TotalDoctorsScreen extends StatefulWidget {
  const TotalDoctorsScreen({super.key});

  @override
  State<TotalDoctorsScreen> createState() => _TotalDoctorsScreenState();
}

class _TotalDoctorsScreenState extends State<TotalDoctorsScreen> {
  // --- DELETE DOCTOR ---
  Future<void> _deleteDoctor(String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Doctor?"),
        content: Text(
            "Are you sure you want to delete Dr. $name?\nThis cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
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
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Doctor deleted successfully")));
    }
  }

  // --- ADD DOCTOR DIALOG ---
  void _showAddDoctorDialog() {
    final _formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final specialCtrl = TextEditingController();
    final bioCtrl = TextEditingController();
    final feesCtrl = TextEditingController();

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Add New Doctor"),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                        controller: nameCtrl,
                        decoration:
                        const InputDecoration(labelText: "Full Name"),
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: "Email"),
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: specialCtrl,
                        decoration: const InputDecoration(
                            labelText: "Specialization (e.g. Cardiologist)"),
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: bioCtrl,
                        decoration: const InputDecoration(labelText: "Bio"),
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: feesCtrl,
                        decoration: const InputDecoration(
                            labelText: "Consultation Fees"),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? "Required" : null),
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
                        .collection('users')
                        .add({
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': 'doctor',
                      'specialization': specialCtrl.text.trim(),
                      'bio': bioCtrl.text.trim(),
                      'fees': feesCtrl.text.trim(),
                      'approved': true,
                      'isProfileCompleted': true,
                      'createdAt': FieldValue.serverTimestamp(),
                      'profileImage': "",
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Doctor Added!")));
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
                    : const Text("Add Doctor",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Total Doctors",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2C97FA),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDoctorDialog,
        backgroundColor: const Color(0xFF2C97FA),
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Doctor", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'doctor')
            .where('approved', isEqualTo: true)
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
                  Icon(Icons.person_off_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 15),
                  Text("No doctors found",
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

              String name = (data['name'] ?? "Unknown").toString();
              String specialization = (data['specialization'] ?? "Specialist").toString();
              // Checks 'fees' AND 'fee' (common typo), defaults to "0", forces String
              String fees = (data['fees'] ?? data['fee'] ?? "0").toString();
              String imageUrl = (data['profileImage'] ??
                  data['imageUrl'] ??
                  data['photoUrl'] ??
                  "")
                  .toString();
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // --- 1. IMAGE AVATAR (With Error Handling) ---
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade50,
                          border: Border.all(
                              color: Colors.blue.shade100, width: 1),
                        ),
                        child: ClipOval(
                          child: (imageUrl.isNotEmpty)
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            // If image loads, great. If not, this builder runs:
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : "D",
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C97FA)),
                                ),
                              );
                            },
                            // Shows spinner while downloading
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2));
                            },
                          )
                              : Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "D",
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C97FA)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),

                      // --- 2. TEXT INFO ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C97FA).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                specialization,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2C97FA),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.monetization_on,
                                    size: 16, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  "\$$fees",
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- 3. DELETE BUTTON ---
                      IconButton(
                        onPressed: () => _deleteDoctor(doc.id, name),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
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