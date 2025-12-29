import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:e_clinic_new/services/cloudinary_service.dart';
import '../providers/theme_provider.dart'; // Import your ThemeProvider

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

  // Time Variables (Defaults)
  String _startTime = "09:00 AM";
  String _endTime = "05:00 PM";

  String _specialization = "Specialist";
  String? _profileImageUrl;
  bool _isEditing = false;
  bool _isLoading = false;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _loadProfileData();
    }
  }

  // 1. Load Data
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

  // 2. Time Picker Logic
  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final localizations = MaterialLocalizations.of(context);
        String formattedTime = localizations.formatTimeOfDay(picked);

        if (isStart) {
          _startTime = formattedTime;
        } else {
          _endTime = formattedTime;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
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

    // --- THEME VARIABLES ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Define dynamic colors based on theme
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor, // Dynamic Background
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Edit Toggle
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.blueAccent),
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                    _imageFile = null;
                  });
                },
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
                        ? NetworkImage(_profileImageUrl!)
                        : null),
                    child: (_imageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 50, color: Colors.blueAccent)
                        : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
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
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            )
                : Text(_nameController.text, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),

            Text(_specialization, style: TextStyle(fontSize: 16, color: subTextColor)),

            const SizedBox(height: 30),

            // --- DETAILS CARD (Includes Dark Mode Toggle) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cardColor, // Dynamic Card Color
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: isDark ? Colors.black26 : Colors.black12,
                        blurRadius: 10,
                        offset: const Offset(0,5)
                    )
                  ]
              ),
              child: Column(
                children: [
                  _buildProfileRow(Icons.email, 'Email', _user!.email ?? "N/A", null, textColor, subTextColor),
                  const Divider(),
                  _buildProfileRow(Icons.phone, 'Phone', _phoneController.text, _phoneController, textColor, subTextColor),
                  const Divider(),

                  // Time Rows
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

                  // --- DARK MODE TOGGLE ---
                  Row(
                    children: [
                      Icon(Icons.dark_mode, color: Colors.blueAccent),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text("Dark Mode", style: TextStyle(color: subTextColor, fontSize: 12)),
                      ),
                      Switch(
                        value: isDark,
                        activeColor: Colors.blueAccent,
                        onChanged: (val) => themeProvider.toggleTheme(val),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            if (_isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text("Log Out"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  // Helper for Time Picking
  Widget _buildTimeRow(IconData icon, String title, String timeValue, bool isStart, Color textColor, Color? subTextColor) {
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
                GestureDetector(
                  onTap: _isEditing ? () => _selectTime(isStart) : null,
                  child: Container(
                    color: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(timeValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
                        if (_isEditing)
                          Icon(Icons.arrow_drop_down, color: subTextColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Standard Helper for Text
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
                  style: TextStyle(color: textColor), // Adapts input color
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