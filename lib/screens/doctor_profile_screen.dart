import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Ensure you have this
import 'package:e_clinic_new/services/cloudinary_service.dart';
import '../providers/theme_provider.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  // Text Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _feesController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Time Variables
  String _startTime = "09:00 AM";
  String _endTime = "05:00 PM";

  String _specialization = "Specialist";
  String? _profileImageUrl;
  bool _isEditing = false;
  bool _isLoading = false;

  // Rating Stats
  double _averageRating = 0.0;
  int _reviewCount = 0;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _loadProfileData();
      _fetchRatingStats(); // Calculate Average Rating
    }
  }

  // 1. Load Profile Data
  Future<void> _loadProfileData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? "Doctor";
          _phoneController.text = data['phone'] ?? "N/A";
          _experienceController.text = (data['experience'] ?? 1).toString();
          _feesController.text = (data['fees'] ?? 1500).toString();
          _bioController.text = data['bio'] ?? "N/A";
          _specialization = data['specialization'] ?? "Specialist";
          _profileImageUrl = data['profileImage'];
          _startTime = data['startTime'] ?? "09:00 AM";
          _endTime = data['endTime'] ?? "05:00 PM";
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  // 2. Fetch & Calculate Ratings
  Future<void> _fetchRatingStats() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('ratings')
          .where('doctorId', isEqualTo: _user!.uid)
          .get();

      if (query.docs.isNotEmpty) {
        double totalStars = 0;
        for (var doc in query.docs) {
          totalStars += (doc['rating'] as num).toDouble();
        }
        setState(() {
          _averageRating = totalStars / query.docs.length;
          _reviewCount = query.docs.length;
        });
      }
    } catch (e) {
      debugPrint("Error calculating ratings: $e");
    }
  }

  // 3. Time Picker Logic
  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final localizations = MaterialLocalizations.of(context);
        String formattedTime = localizations.formatTimeOfDay(picked);
        if (isStart) _startTime = formattedTime;
        else _endTime = formattedTime;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    String? newImageUrl = _profileImageUrl;

    try {
      if (_imageFile != null) {
        newImageUrl = await CloudinaryService().uploadImage(_imageFile!);
        if (newImageUrl == null) throw Exception("Image upload failed");
      }

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'experience': int.tryParse(_experienceController.text) ?? 1,
        'fees': int.tryParse(_feesController.text) ?? 1500,
        'bio': _bioController.text.trim(),
        'profileImage': newImageUrl,
        'startTime': _startTime,
        'endTime': _endTime,
      });

      setState(() {
        _profileImageUrl = newImageUrl;
        _isEditing = false;
        _imageFile = null;
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Center(child: CircularProgressIndicator());

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Edit Toggle
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.blueAccent),
                onPressed: () => setState(() {
                  _isEditing = !_isEditing;
                  _imageFile = null;
                }),
              ),
            ),

            const SizedBox(height: 10),

            // Profile Image Picker
            GestureDetector(
              onTap: _isEditing ? _pickImage : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!) as ImageProvider
                        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(_profileImageUrl!)
                        : null),
                    child: (_imageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 50, color: Colors.blueAccent)
                        : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // Name Field
            _isEditing
                ? TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                hintText: "Enter Name",
                hintStyle: TextStyle(color: subTextColor),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            )
                : Text(_nameController.text, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),

            Text(_specialization, style: TextStyle(fontSize: 16, color: subTextColor)),

            // --- AVERAGE RATING BADGE ---
            if (!_isEditing) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      "${_averageRating.toStringAsFixed(1)} ($_reviewCount Reviews)",
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            // --- DETAILS CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black12, blurRadius: 10, offset: const Offset(0,5))]
              ),
              child: Column(
                children: [
                  _buildProfileRow(Icons.email, 'Email', _user!.email ?? "N/A", null, textColor, subTextColor),
                  const Divider(),
                  _buildProfileRow(Icons.phone, 'Phone', _phoneController.text, _phoneController, textColor, subTextColor),
                  const Divider(),
                  _buildTimeRow(Icons.access_time, "Start Time", _startTime, true, textColor, subTextColor),
                  const Divider(),
                  _buildTimeRow(Icons.access_time_filled, "End Time", _endTime, false, textColor, subTextColor),
                  const Divider(),
                  _buildProfileRow(Icons.work, 'Experience (Years)', _experienceController.text, _experienceController, textColor, subTextColor, isNumber: true),
                  const Divider(),
                  _buildProfileRow(Icons.monetization_on, 'Fees (PKR)', _feesController.text, _feesController, textColor, subTextColor, isNumber: true),
                  const Divider(),
                  _buildProfileRow(Icons.info, 'Bio', _bioController.text, _bioController, textColor, subTextColor, maxLines: 3),

                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.dark_mode, color: Colors.blueAccent),
                      const SizedBox(width: 20),
                      Expanded(child: Text("Dark Mode", style: TextStyle(color: subTextColor, fontSize: 12))),
                      Switch(value: isDark, activeColor: Colors.blueAccent, onChanged: (val) => themeProvider.toggleTheme(val))
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 4. RECENT REVIEWS SECTION ---
            if (!_isEditing) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Latest Reviews", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              ),
              const SizedBox(height: 15),
              _buildReviewsList(isDark, textColor, subTextColor),
              const SizedBox(height: 30),
            ],

            // Save/Logout Buttons
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text("Log Out"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              )
          ],
        ),
      ),
    );
  }

  // --- WIDGET: REVIEWS LIST ---
  Widget _buildReviewsList(bool isDark, Color textColor, Color? subTextColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('doctorId', isEqualTo: _user!.uid)
          .orderBy('timestamp', descending: true) // This requires an Index!
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Check for Errors (likely "Failed to find index")
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(10),
            color: Colors.red.withOpacity(0.1),
            child: Text(
              "Error loading reviews: ${snapshot.error}",
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No reviews yet.", style: TextStyle(color: subTextColor)));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildReviewItem(data, isDark, textColor, subTextColor);
          },
        );
      },
    );
  }

  // --- WIDGET: SINGLE REVIEW ITEM (Fetches Patient Info) ---
  Widget _buildReviewItem(Map<String, dynamic> reviewData, bool isDark, Color textColor, Color? subTextColor) {
    final String patientId = reviewData['patientId'] ?? "";
    final double rating = (reviewData['rating'] ?? 0).toDouble();
    final String comment = reviewData['comment'] ?? "No comment";

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(patientId).get(),
      builder: (context, snapshot) {
        String patientName = "Anonymous";
        String? patientImage;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          patientName = userData['name'] ?? "Anonymous";
          patientImage = userData['profileImage'] ?? userData['imageUrl'];
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    backgroundImage: patientImage != null ? CachedNetworkImageProvider(patientImage) : null,
                    child: patientImage == null ? const Icon(Icons.person, color: Colors.blueAccent) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                        Row(
                          children: List.generate(5, (index) => Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            size: 14, color: Colors.amber,
                          )),
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(comment, style: TextStyle(color: subTextColor, fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ),
        );
      },
    );
  }

  // --- HELPERS ---
  Widget _buildTimeRow(IconData icon, String title, String timeValue, bool isStart, Color textColor, Color? subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: subTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _isEditing ? () => _selectTime(isStart) : null,
                  child: Row(
                    children: [
                      Text(timeValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
                      if (_isEditing) Icon(Icons.arrow_drop_down, color: subTextColor),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String title, String value, TextEditingController? controller, Color textColor, Color? subTextColor, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: subTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                (_isEditing && controller != null)
                    ? TextField(
                  controller: controller,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  maxLines: maxLines,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 5)),
                )
                    : Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
              ],
            ),
          )
        ],
      ),
    );
  }
}