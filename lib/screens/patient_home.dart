import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; // IMPORT THIS PACKAGE

import 'appointments_list.dart';
import 'patient_profile_screen.dart';
import 'patient_history_screen.dart'; // IMPORT YOUR HISTORY SCREEN

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  String _searchQuery = "";
  String _selectedCategory = "All"; // Filter State

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // List of Specializations for the Filter
  final List<String> _specializations = [
    "All",
    "General",
    "Cardiologist",
    "Dentist",
    "Neurologist",
    "Orthopedic",
    "Dermatologist"
  ];

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

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
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

  // --- DOCTOR CARD (Optimized with CachedImage) ---
  Widget _buildDoctorTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final name = (data['name'] ?? 'Unknown').toString();
    final specialization = (data['specialization'] ?? 'General').toString();
    final experience = (data['experience'] ?? '0').toString();
    final fees = (data['fees'] ?? '0').toString();

    final startTiming = (data['start_timing'] ?? data['startTime'] ?? '--').toString();
    final endTiming = (data['end_timing'] ?? data['endTime'] ?? '--').toString();

    // Image Logic
    String displayImage = '';
    if (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty) {
      displayImage = data['profileImage'].toString();
    } else if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
      displayImage = data['imageUrl'].toString();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/doctor_detail', arguments: {'doctorId': doc.id});
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // LAYER 1: Background & Image
          Container(
            margin: const EdgeInsets.only(bottom: 60.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E9EAB), Color(0xFFeef2f3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    // FIX 3: CachedNetworkImage prevents reloading on scroll
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // LAYER 2: Info Card
          Container(
            height: 145,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                    ),
                    Text(
                      specialization,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subTextColor),
                    ),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, size: 14, color: Colors.blueAccent),
                        const SizedBox(width: 4),
                        Text("$experience Yrs", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.access_time_filled, size: 14, color: Colors.orangeAccent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              startTiming,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  width: double.infinity,
                  height: 36,
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
                    child: const Text("Book Appointment", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HOME TAB WITH FILTERS ---
  Widget _buildHomeTab() {
    final Stream<QuerySnapshot> stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('approved', isEqualTo: true)
        .where('isProfileCompleted', isEqualTo: true)
        .snapshots();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header Area
        Container(
          padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.blueAccent,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const Text("E-Clinic", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                    onPressed: _logout,
                  )
                ],
              ),
              const SizedBox(height: 20),
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search doctor...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    }) : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // FIX 2: Specialization Filters
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _specializations.length,
                  itemBuilder: (context, index) {
                    final cat = _specializations[index];
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : (isDark ? Colors.grey[700] : Colors.blue[400]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.blueAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return _buildEmptyState("No doctors available yet.");

              // FILTERING LOGIC
              final filtered = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final name = (data['name'] ?? '').toString().toLowerCase();
                final specialization = (data['specialization'] ?? '').toString().toLowerCase();

                // 1. Search Query Check
                final matchesSearch = name.contains(_searchQuery) || specialization.contains(_searchQuery);

                // 2. Category Check
                bool matchesCategory = true;
                if (_selectedCategory != "All") {
                  matchesCategory = specialization.contains(_selectedCategory.toLowerCase());
                }

                return matchesSearch && matchesCategory;
              }).toList();

              if (filtered.isEmpty) {
                return _buildEmptyState("No doctors found.");
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIX 4: Renamed "Top Doctors" -> "Our Doctors"
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15.0, left: 4),
                      child: Text(
                        "Our Doctors",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: filtered.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.60,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemBuilder: (context, index) {
                          return _buildDoctorTile(filtered[index]);
                        },
                      ),
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

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX 1: Add History Screen to tabs
    final tabs = [
      _buildHomeTab(),
      const AppointmentsList(),
      const PatientHistoryScreen(), // Shows Patient History
      const PatientProfileScreen(),
    ];

    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
                  displayImage = data['imageUrl'].toString();
                } else if (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty) {
                  displayImage = data['profileImage'].toString();
                }
              }

              final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      currentAccountPicture: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: CircleAvatar(
                          backgroundImage: displayImage.isNotEmpty ? CachedNetworkImageProvider(displayImage) : null,
                          backgroundColor: Colors.white,
                          child: displayImage.isEmpty ? Text(_getInitials(name), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: drawerHeaderColor)) : null,
                        ),
                      ),
                    ),
                    // Navigation Options including History
                    ListTile(
                        leading: const Icon(Icons.home_rounded, color: Colors.blueAccent),
                        title: Text('Home', style: TextStyle(color: drawerTextColor)),
                        onTap: () { setState(() => _selectedIndex = 0); Navigator.pop(context); }
                    ),
                    ListTile(
                        leading: const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent),
                        title: Text('Appointments', style: TextStyle(color: drawerTextColor)),
                        onTap: () { setState(() => _selectedIndex = 1); Navigator.pop(context); }
                    ),
                    ListTile(
                        leading: const Icon(Icons.history_rounded, color: Colors.blueAccent),
                        title: Text('Medical History', style: TextStyle(color: drawerTextColor)),
                        onTap: () { setState(() => _selectedIndex = 2); Navigator.pop(context); }
                    ),
                    ListTile(
                        leading: const Icon(Icons.person_rounded, color: Colors.blueAccent),
                        title: Text('Profile', style: TextStyle(color: drawerTextColor)),
                        onTap: () { setState(() => _selectedIndex = 3); Navigator.pop(context); }
                    ),
                    const Divider(),
                    ListTile(
                        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                        onTap: () { Navigator.pop(context); _logout(); }
                    ),
                  ],
                ),
              );
            }
        ),
      ),
      body: tabs[_selectedIndex],

      // FIX 1: Updated Bottom Navigation with History
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