import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cloudinary_service.dart';
import '../providers/theme_provider.dart'; // Import your ThemeProvider

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

  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  File? _pickedImage;
  String? _networkImageUrl;
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
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameCtrl.text = data['name'] ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _addressCtrl.text = data['address'] ?? '';
          _networkImageUrl = data['imageUrl'];
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
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
        if (imageUrl == null) {
          throw Exception('Image upload failed');
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'imageUrl': imageUrl,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameCtrl.text.trim());
      if(imageUrl != null) await prefs.setString('imageUrl', imageUrl);

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));

      setState(() {
        _isEditing = false;
        _networkImageUrl = imageUrl;
        _pickedImage = null;
      });

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. LISTEN TO PROVIDER for Dark Mode state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // 2. Use Standard Theme Colors (Defined in main.dart)
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      // Background color is handled automatically by 'main.dart' theme now
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER SECTION ---
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _pickedImage != null
                                ? FileImage(_pickedImage!)
                                : (_networkImageUrl != null && _networkImageUrl!.isNotEmpty
                                ? NetworkImage(_networkImageUrl!)
                                : null) as ImageProvider?,
                            child: _pickedImage == null && (_networkImageUrl == null || _networkImageUrl!.isEmpty)
                                ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                                : null,
                          ),
                        ),
                        if (_isEditing)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 20),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _nameCtrl.text.isNotEmpty ? _nameCtrl.text : "Patient Name",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? "",
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- FORM SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField("Full Name", _nameCtrl, Icons.person, cardColor, textColor, labelColor!),
                    const SizedBox(height: 15),
                    _buildTextField("Phone Number", _phoneCtrl, Icons.phone, cardColor, textColor, labelColor),
                    const SizedBox(height: 15),
                    _buildTextField("Address", _addressCtrl, Icons.location_on, cardColor, textColor, labelColor),

                    const SizedBox(height: 30),
                    const Divider(),

                    // --- DARK MODE SWITCH (Connected to Provider) ---
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.dark_mode, color: Colors.purple),
                      ),
                      title: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      trailing: Switch(
                        value: isDark, // Value from Provider
                        activeColor: Colors.purple,
                        onChanged: (value) {
                          // Action updates Provider
                          themeProvider.toggleTheme(value);
                        },
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.logout, color: Colors.redAccent),
                      ),
                      title: Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      onTap: () => _logout(context),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      Color bgColor,
      Color txtColor,
      Color lblColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        // Add shadow only in Light Mode for depth
        boxShadow: Theme.of(context).brightness == Brightness.light ? [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ] : [],
      ),
      child: TextFormField(
        controller: controller,
        enabled: _isEditing,
        style: TextStyle(color: txtColor),
        validator: (val) => val!.isEmpty ? '$label cannot be empty' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: lblColor),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}