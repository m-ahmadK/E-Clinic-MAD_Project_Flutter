import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TotalPatientsScreen extends StatefulWidget {
  const TotalPatientsScreen({super.key});

  @override
  State<TotalPatientsScreen> createState() => _TotalPatientsScreenState();
}

class _TotalPatientsScreenState extends State<TotalPatientsScreen> {
  // --- DELETE PATIENT ---
  Future<void> _deletePatient(String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Patient?"),
        content: Text(
            "Are you sure you want to delete $name?\nThis cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Patient deleted successfully")));
    }
  }

  // --- ADD PATIENT DIALOG ---
  void _showAddPatientDialog() {
    final _formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ageCtrl = TextEditingController();

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Add New Patient"),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: "Full Name"),
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: "Email"),
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: "Phone Number"),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: ageCtrl,
                        decoration: const InputDecoration(labelText: "Age"),
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
                    await FirebaseFirestore.instance.collection('users').add({
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'age': ageCtrl.text.trim(),
                      'role': 'patient', // Important: Set role to patient
                      'createdAt': FieldValue.serverTimestamp(),
                      'profileImage': "", // Placeholder
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Patient Added!")));
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
                    : const Text("Add Patient",
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
        title: const Text("Total Patients",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2C97FA),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPatientDialog,
        backgroundColor: const Color(0xFF2C97FA),
        elevation: 4,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Add Patient", style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // --- QUERY CHANGED: Looking for role == 'patient' ---
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
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
                  Icon(Icons.groups_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 15),
                  Text("No patients found",
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

              // --- ROBUST PARSING (Same safety checks as Doctors) ---
              String name = (data['name'] ?? "Unknown Patient").toString();
              String email = (data['email'] ?? "No Email").toString();
              String phone = (data['phone'] ?? "No Phone").toString();
              String age = (data['age'] ?? "").toString();

              // Handle multiple image field names just in case
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
                      // --- 1. AVATAR ---
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purple.shade50, // Different color for patients
                          border: Border.all(
                              color: Colors.purple.shade100, width: 1),
                        ),
                        child: ClipOval(
                          child: (imageUrl.isNotEmpty)
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : "P",
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2));
                            },
                          )
                              : Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "P",
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),

                      // --- 2. INFO ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.email_outlined,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (phone != "No Phone") ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.phone_android,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),

                      // --- 3. DELETE BUTTON ---
                      IconButton(
                        onPressed: () => _deletePatient(doc.id, name),
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