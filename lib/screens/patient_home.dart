import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'appointments_list.dart';
import 'patient_profile_screen.dart';
import 'patient_history_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  String _searchQuery = "";
  String _selectedCategory = "All";

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Categories with Icons
  final Map<String, IconData> _categoryIcons = {
    "All": Icons.medical_services_outlined,
    "General": Icons.health_and_safety_outlined,
    "Cardiologist": Icons.favorite_border,
    "Dentist": Icons.masks_outlined,
    "Neurologist": Icons.psychology_outlined,
    "Orthopedic": Icons.accessibility_new_outlined,
    "Dermatologist": Icons.face_outlined,
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        if (!mounted) return;
        setState(() => _searchQuery = q);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    final nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length > 1 && nameParts[0].isNotEmpty && nameParts[1].isNotEmpty) {
      return "${nameParts[0][0]}${nameParts[1][0]}".toUpperCase();
    }
    if (name.length > 1) return name.substring(0, 2).toUpperCase();
    return name[0].toUpperCase();
  }

  Widget _buildDoctorTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final name = (data['name'] ?? 'Unknown').toString();
    final specialization = (data['specialization'] ?? 'General').toString();
    // final experience = (data['experience'] ?? '1').toString(); // Unused in UI currently
    final fees = (data['fees'] ?? '0').toString();
    final rating = (data['rating'] ?? '4.8').toString();
    final hospital = data['hospital'] ?? "City Hospital";

    final startTiming = (data['start_timing'] ?? data['startTime'] ?? '--').toString();
    final endTiming = (data['end_timing'] ?? data['endTime'] ?? '--').toString();

    String displayImage = '';
    if (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty) {
      displayImage = data['profileImage'].toString();
    } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
      displayImage = data['imageUrl'].toString();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/doctor_detail', arguments: {'doctorId': doc.id});
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // LAYER 1: Gradient Background & Image
          Container(
            margin: const EdgeInsets.only(bottom: 50.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E9EAB), Color(0xFFeef2f3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: displayImage.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: displayImage,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.person, size: 40, color: Colors.white)),
                    )
                        : const Center(child: Icon(Icons.person, size: 40, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),

          // LAYER 2: Info Card
          Container(
            height: 125,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dr. $name",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                    ),
                    Text(
                      specialization,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blueAccent),
                    ),
                  ],
                ),

                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    Text(" $rating ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
                    Expanded(
                      child: Text(
                        "• $hospital",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: subTextColor),
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/book_appointment', arguments: {
                        'doctorId': doc.id,
                        'doctorName': name,
                        'start_timing': startTiming,
                        'end_timing': endTiming,
                        'fees': fees
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text("Book • $fees PKR", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HOME TAB CONTENT ---
  Widget _buildHomeTab() {
    final Stream<QuerySnapshot> stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('approved', isEqualTo: true)
        .where('isProfileCompleted', isEqualTo: true)
        .snapshots();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = const Color(0xFF4A90E2);
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : headerColor,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),

                  // --- CHANGE 1: Welcome Name instead of Location ---
                  StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                      builder: (context, snapshot) {
                        String userName = "Guest";
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          userName = data['name'] ?? "Patient";
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text("Welcome Back,", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                                userName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                          ],
                        );
                      }
                  ),
                  // --------------------------------------------------

                  // --- CHANGE 2: Navigate to Notifications ---
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () {
                      Navigator.pushNamed(context, '/notifications');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text("Let's Find Your\nSpecialist", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
              const SizedBox(height: 20),

              // Search
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "Search doctor name...",
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];

              // Filter
              final filtered = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final name = (data['name'] ?? '').toString().toLowerCase();
                final specialization = (data['specialization'] ?? '').toString().toLowerCase();
                final matchesSearch = name.contains(_searchQuery) || specialization.contains(_searchQuery);

                bool matchesCategory = true;
                if (_selectedCategory != "All") {
                  matchesCategory = specialization.contains(_selectedCategory.toLowerCase());
                }
                return matchesSearch && matchesCategory;
              }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categories
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categoryIcons.length,
                        itemBuilder: (context, index) {
                          String catName = _categoryIcons.keys.elementAt(index);
                          IconData catIcon = _categoryIcons.values.elementAt(index);
                          bool isSelected = _selectedCategory == catName;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = catName),
                            child: Container(
                              width: 70,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: isSelected ? headerColor : (isDark ? Colors.grey[800] : Colors.white),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0,2))]
                                    ),
                                    child: Icon(catIcon, color: isSelected ? Colors.white : headerColor, size: 24),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(catName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white : Colors.grey[700], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Our Doctors", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        ],
                    ),
                    const SizedBox(height: 15),

                    // Grid
                    filtered.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No doctors found")))
                        : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                      itemBuilder: (context, index) {
                        return _buildDoctorTile(filtered[index]);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      const AppointmentsList(),
      const PatientHistoryScreen(),
      const PatientProfileScreen(),
    ];

    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/chat_list');
        },
        backgroundColor: Colors.blueAccent,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),

      drawer: Drawer(
        child: currentUser == null
            ? const SizedBox()
            : StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
            builder: (context, snapshot) {
              String name = "Patient";
              String email = currentUser.email ?? "";
              String displayImage = "";

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? "Patient";
                if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) displayImage = data['imageUrl'].toString();
                else if (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty) displayImage = data['profileImage'].toString();
              }

              final drawerHeaderColor = isDark ? const Color(0xFF1E1E1E) : Colors.blueAccent;
              final drawerTextColor = isDark ? Colors.white : Colors.black87;

              return Container(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    UserAccountsDrawerHeader(
                      decoration: BoxDecoration(color: drawerHeaderColor),
                      accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      accountEmail: Text(email, style: const TextStyle(fontSize: 14)),
                      currentAccountPicture: CircleAvatar(
                        backgroundImage: displayImage.isNotEmpty ? CachedNetworkImageProvider(displayImage) : null,
                        backgroundColor: Colors.white,
                        child: displayImage.isEmpty ? Text(_getInitials(name), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: drawerHeaderColor)) : null,
                      ),
                    ),
                    ListTile(leading: const Icon(Icons.home, color: Colors.blueAccent), title: Text('Home', style: TextStyle(color: drawerTextColor)), onTap: () { setState(() => _selectedIndex = 0); Navigator.pop(context); }),
                    ListTile(leading: const Icon(Icons.calendar_month, color: Colors.blueAccent), title: Text('Appointments', style: TextStyle(color: drawerTextColor)), onTap: () { setState(() => _selectedIndex = 1); Navigator.pop(context); }),
                    ListTile(leading: const Icon(Icons.chat_bubble, color: Colors.blueAccent), title: Text('My Chats', style: TextStyle(color: drawerTextColor)), onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/chat_list'); }),
                    ListTile(leading: const Icon(Icons.history, color: Colors.blueAccent), title: Text('History', style: TextStyle(color: drawerTextColor)), onTap: () { setState(() => _selectedIndex = 2); Navigator.pop(context); }),
                    ListTile(leading: const Icon(Icons.person, color: Colors.blueAccent), title: Text('Profile', style: TextStyle(color: drawerTextColor)), onTap: () { setState(() => _selectedIndex = 3); Navigator.pop(context); }),
                    const Divider(),
                    ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Logout', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(context); _logout(); }),
                  ],
                ),
              );
            }
        ),
      ),
      body: tabs[_selectedIndex],

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Appointments'),
            BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}