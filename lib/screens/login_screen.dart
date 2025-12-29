// lib/screens/login_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  bool _initializedFromArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is String && args.isNotEmpty) {
        _emailCtrl.text = args;
      } else if (args is Map && args['email'] is String) {
        _emailCtrl.text = args['email'];
      }

      _initializedFromArgs = true;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter email';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ------------------------------------------------------------------------
  // 🔥 UPDATED LOGIN LOGIC WITH DOCTOR PROFILE CHECK + APPROVAL CHECK
  // ------------------------------------------------------------------------
  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception('Login failed');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No user profile found. Please sign up or contact support.')),
        );
        return;
      }

      final data = doc.data()!;
      final role = (data['role'] ?? 'patient').toString();
      final name = (data['name'] ?? '').toString();

      final bool isProfileCompleted = data['isProfileCompleted'] == true;
      final bool isApproved = data['approved'] == true;

      // --------------------------------------------------------------------
      // 🔥 DOCTOR MUST COMPLETE PROFILE FIRST
      // --------------------------------------------------------------------
      if (role == 'doctor') {
        if (!isProfileCompleted) {
          Navigator.pushReplacementNamed(context, '/doctor_form');
          return;
        }

        // --------------------------------------------------------------------
        // 🔥 AFTER PROFILE → NEED ADMIN APPROVAL
        // --------------------------------------------------------------------
        if (!isApproved) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;

          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Profile under review'),
              content: const Text(
                  'Your profile is submitted and waiting for admin approval.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                )
              ],
            ),
          );
          return;
        }
      }

      // --------------------------------------------------------------------
      // SAVE DATA LOCALLY
      // --------------------------------------------------------------------
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', user.uid);
      await prefs.setString('name', name);
      await prefs.setString('email', email);
      await prefs.setString('role', role);
      //if (name.isNotEmpty) prefs.setString('name', name);

      // --------------------------------------------------------------------
      // REDIRECT BASED ON ROLE
      // --------------------------------------------------------------------
      if (!mounted) return;

      if (role == 'doctor') {
        Navigator.pushReplacementNamed(context, '/doctor_home');
      } else {
        Navigator.pushReplacementNamed(context, '/patient_home');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') {
        msg = 'No account found for that email';
      } else if (e.code == 'wrong-password') msg = 'Incorrect password';
      else if (e.message != null) msg = e.message!;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
      debugPrint('Login error: $e\n$st');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 700 ? 600.0 : width * 0.95;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.medical_services,
                          size: 72, color: Colors.blueAccent),
                      const SizedBox(height: 8),
                      const Text('E-Clinic',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder()),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onLoginPressed,
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                              : const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child:
                            Text('Login', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushReplacementNamed(
                            context, '/signup'),
                        child: const Text("Don't have an account? Sign up"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
