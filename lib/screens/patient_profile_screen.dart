import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cloudinary_service.dart';
import '../providers/theme_provider.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _genderCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();
  final TextEditingController _bloodGroupCtrl = TextEditingController();

  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  File? _pickedImage;
  String? _networkImageUrl;
  String? _email = "";
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _email = user.email;
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameCtrl.text = data['name'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _addressCtrl.text = data['address'] ?? '';
          _genderCtrl.text = data['gender'] ?? '';
          _dobCtrl.text = data['dob'] ?? '';
          _bloodGroupCtrl.text = data['bloodGroup'] ?? '';
          _networkImageUrl = data['profileImage'] ?? data['imageUrl'];
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? imageUrl = _networkImageUrl;

      if (_pickedImage != null) {
        imageUrl = await _cloudinaryService.uploadImage(_pickedImage!);
        if (imageUrl == null) throw Exception('Image upload failed');
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'gender': _genderCtrl.text.trim(),
        'dob': _dobCtrl.text.trim(),
        'bloodGroup': _bloodGroupCtrl.text.trim(),
        'profileImage': imageUrl, // Standardized key
      });

      // Update Shared Prefs for local usage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameCtrl.text.trim());
      if (imageUrl != null) await prefs.setString('imageUrl', imageUrl);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated Successfully!')));

      setState(() {
        _isEditing = false;
        _networkImageUrl = imageUrl;
        _pickedImage = null;
      });

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Theme Variables
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final headerColor = Colors.blueAccent;
    final bgColor = headerColor;
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF222B45);
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[500];
    final iconColor = Colors.blueAccent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: headerColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.white),
            onPressed: () {
              if (_isEditing) _saveProfile();
              else setState(() => _isEditing = true);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
        children: [
          // --- TOP SECTION (Profile Pic) ---
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white,
                      backgroundImage: _pickedImage != null
                          ? FileImage(_pickedImage!)
                          : (_networkImageUrl != null && _networkImageUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(_networkImageUrl!)
                          : null) as ImageProvider?,
                      child: _pickedImage == null && (_networkImageUrl == null || _networkImageUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                  ),
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 20),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _nameCtrl.text.isEmpty ? "Patient Name" : _nameCtrl.text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            _email ?? "",
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 25),

          // --- BOTTOM CONTAINER (Form) ---
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Personal Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 20),

                      // Fields
                      _buildInfoTile("Full Name", _nameCtrl, Icons.person, isDark, textColor, labelColor, iconColor),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: _buildInfoTile("Gender", _genderCtrl, Icons.male, isDark, textColor, labelColor, iconColor)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildInfoTile("Date of Birth", _dobCtrl, Icons.calendar_today, isDark, textColor, labelColor, iconColor)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: _buildInfoTile("Phone", _phoneCtrl, Icons.phone, isDark, textColor, labelColor, iconColor)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildInfoTile("Blood Group", _bloodGroupCtrl, Icons.bloodtype, isDark, textColor, labelColor, Colors.redAccent)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildInfoTile("Address", _addressCtrl, Icons.location_on, isDark, textColor, labelColor, iconColor),

                      const SizedBox(height: 30),
                      Divider(color: Colors.grey.withOpacity(0.2)),
                      const SizedBox(height: 10),

                      // Settings Section
                      Text("Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 15),

                      // Dark Mode
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.dark_mode, color: Colors.purple),
                            ),
                            const SizedBox(width: 15),
                            Expanded(child: Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w600, color: textColor))),
                            Switch(
                              value: isDark,
                              activeColor: Colors.blueAccent,
                              onChanged: (val) => themeProvider.toggleTheme(val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Logout
                      GestureDetector(
                        onTap: () => _logout(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.logout, color: Colors.redAccent),
                              ),
                              const SizedBox(width: 15),
                              Text("Log Out", style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DYNAMIC TILE: Switches between Read-Only (Beautiful) and Edit (TextField) ---
  Widget _buildInfoTile(
      String label,
      TextEditingController controller,
      IconData icon,
      bool isDark,
      Color textColor,
      Color? labelColor,
      Color iconColor) {

    // VIEW MODE
    if (!_isEditing) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.isEmpty ? "N/A" : controller.text,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // EDIT MODE
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
          ),
          child: TextFormField(
            controller: controller,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: iconColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              hintText: "Enter $label",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}