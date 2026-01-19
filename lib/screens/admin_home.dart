import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}


class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // --- LOGOUT LOGIC ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  void initState() {
    super.initState();
    print("ADMIN UID: ${FirebaseAuth.instance.currentUser?.uid}");
  }
  // --- APPROVE DOCTOR ---
  Future<void> _approveDoctor(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'approved': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Doctor Approved Successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. DOCTORS STREAM (Fetch ALL doctors, we filter 'approved' in the UI to avoid Index Error)
    final doctorStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .snapshots();

    // 2. PATIENTS STREAM
    final patientStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots();

    // 3. APPOINTMENTS STREAM
    final appointmentStream = FirebaseFirestore.instance
        .collection('appointments')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light Grey Background

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          automaticallyImplyLeading: false,
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.white),
              SizedBox(width: 10),
              Text("Admin Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2C97FA), Color(0xFF00C6FB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 5,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
              tooltip: "Logout",
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Overview",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 20),

            // --- STATS ROW 1 ---
            Row(
              children: [
                Expanded(
                  child: _buildDashboardCard(
                    title: "Doctors",
                    icon: Icons.medical_services,
                    colorStart: const Color(0xFF4facfe),
                    colorEnd: const Color(0xFF00f2fe),
                    stream: doctorStream,
                    onTap: () => Navigator.pushNamed(context, '/total_doctors'),
                    // FILTER: Only count if 'approved' is true
                    filterLogic: (doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['approved'] == true;
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildDashboardCard(
                    title: "Patients",
                    icon: Icons.person,
                    colorStart: const Color(0xFFfa709a),
                    colorEnd: const Color(0xFFfee140),
                    stream: patientStream,
                    onTap: () => Navigator.pushNamed(context, '/total_patients'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // --- STATS ROW 2 ---
            _buildDashboardCard(
              title: "Total Appointments",
              icon: Icons.calendar_today,
              colorStart: const Color(0xFF43e97b),
              colorEnd: const Color(0xFF38f9d7),
              stream: appointmentStream,
              onTap: () => Navigator.pushNamed(context, '/total_appointments'),
              isFullWidth: true,
            ),

            const SizedBox(height: 30),

            // --- PENDING APPROVALS HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pending Approvals",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text("Action Needed", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // --- PENDING LIST ---
            _buildPendingDoctorsList(),
          ],
        ),
      ),
    );
  }

  // --- HELPER: DASHBOARD CARD (With Client-Side Filtering) ---
  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Color colorStart,
    required Color colorEnd,
    required Stream<QuerySnapshot> stream,
    required VoidCallback onTap,
    bool Function(QueryDocumentSnapshot)? filterLogic, // New parameter for filtering
    bool isFullWidth = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [colorStart, colorEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: colorStart.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5)),
          ],
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            // 1. Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            // 2. Error
            if (snapshot.hasError) {
              return Center(
                child: Text("Error: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              );
            }

            // 3. Success (Calculate Count Locally)
            String count = "0";
            if (snapshot.hasData) {
              var docs = snapshot.data!.docs;

              // Apply filter if provided (e.g., only approved doctors)
              if (filterLogic != null) {
                docs = docs.where(filterLogic).toList();
              }

              count = docs.length.toString();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    if (!isFullWidth)
                      const Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
                  ],
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          count,
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- HELPER: PENDING DOCTORS LIST ---
  Widget _buildPendingDoctorsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('approved', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 60, color: Colors.green.withOpacity(0.3)),
                const SizedBox(height: 10),
                const Text("All caught up!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const Text("No pending approvals.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      (data['name'] ?? "D").substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] ?? "Unknown Doctor",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          data['specialization'] ?? "Specialist",
                          style: TextStyle(color: Colors.blue[400], fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          data['email'] ?? "",
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _approveDoctor(doc.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853), // Success Green
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text("Approve", style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}