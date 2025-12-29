import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_clinic_new/services/cloudinary_service.dart';

class DoctorProfileFormScreen extends StatefulWidget {
  const DoctorProfileFormScreen({super.key});

  @override
  State<DoctorProfileFormScreen> createState() => _DoctorProfileFormScreenState();
}

class _DoctorProfileFormScreenState extends State<DoctorProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _specializationCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _pmdcCtrl = TextEditingController(); // License Number
  final TextEditingController _startTimingCtrl = TextEditingController();
  final TextEditingController _endTimingCtrl = TextEditingController();
  final TextEditingController _experienceCtrl = TextEditingController();
  final TextEditingController _feesCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool _isLoading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
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

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a profile image.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final imageUrl = await _cloudinaryService.uploadImage(_pickedImage!);
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'specialization': _specializationCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'pmdc_number': _pmdcCtrl.text.trim(),
        'start_timing': _startTimingCtrl.text.trim(),
        'end_timing': _endTimingCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'fees': _feesCtrl.text.trim(),
        'imageUrl': imageUrl,
        'isProfileCompleted': true,
        'approved': false,
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Profile Submitted'),
          content: const Text('Your profile is under review by the admin. You will be able to log in once approved.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Doctor Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Additional Information Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _pickedImage != null ? FileImage(_pickedImage!) : null,
                    child: _pickedImage == null
                        ? const Icon(Icons.add_a_photo, size: 50)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _specializationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Specialization (e.g. Cardiologist)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _experienceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Experience (2-3 years)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _startTimingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Start Timing(e.g. 11:00am)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _endTimingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'End Timing(e.g. 2:00am)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _pmdcCtrl,
                  decoration: const InputDecoration(
                    labelText: 'PMDC / License Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _feesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fees (e.g. 1500)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'About Yourself/BIO',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Submit Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
