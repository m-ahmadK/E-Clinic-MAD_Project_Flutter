import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _rememberMe = false;

  // --- GOOGLE SIGN-IN LOGIC (UPDATED) ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. FORCE ACCOUNT PICKER:
      // We sign out of the Google Plugin first to clear the cache.
      // This forces the "Choose an Account" popup to appear every time.
      await GoogleSignIn().signOut();

      // 2. Start the Sign In process
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User canceled the picker
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': user.displayName ?? "Unknown",
            'email': user.email,
            'role': 'patient',
            'profileImage': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        final role = userDoc.exists ? (userDoc['role'] ?? 'patient') : 'patient';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', user.uid);
        await prefs.setString('role', role);
        await prefs.setString('name', user.displayName ?? "");

        if (!mounted) return;

        if (role == 'doctor') {
          Navigator.pushReplacementNamed(context, '/doctor_home');
        } else if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin_home');
        } else {
          Navigator.pushReplacementNamed(context, '/patient_home');
        }
      }
    } catch (e) {
      _showErrorSnackBar("Google Sign-In failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REGULAR EMAIL LOGIN ---
  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String email = _emailCtrl.text.trim();
    String password = _passCtrl.text.trim();

    try {
      // 1. Authenticate
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;

      if (user != null) {
        // 2. Check Firestore Role
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!doc.exists) throw Exception("User profile not found.");

        final data = doc.data()!;
        final role = (data['role'] ?? 'patient').toString();
        final name = (data['name'] ?? '').toString();

        // 3. Role-Specific Logic
        if (role == 'doctor') {
          if (data['isProfileCompleted'] != true) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/doctor_form');
            return;
          }
          if (data['approved'] != true) {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            _showDialog("Under Review", "Your account is waiting for admin approval.");
            return;
          }
        }

        // 4. Save Session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', user.uid);
        await prefs.setString('role', role);
        await prefs.setString('name', name);

        if (!mounted) return;

        // 5. Navigate
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin_home');
        } else if (role == 'doctor') {
          Navigator.pushReplacementNamed(context, '/doctor_home');
        } else {
          Navigator.pushReplacementNamed(context, '/patient_home');
        }
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FORGOT PASSWORD POP-UP ---
  void _showForgotPasswordDialog(bool isDarkMode) {
    String email = _emailCtrl.text.trim();

    // Dialog Colors based on Dark Mode
    Color dialogBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    Color dialogText = isDarkMode ? Colors.white : Colors.black;
    Color subText = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    Color boxColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100]!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Center(
              child: Text("Verification Code",
                  style: TextStyle(fontWeight: FontWeight.bold, color: dialogText))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "We have sent a 6-digit verification code to:",
                textAlign: TextAlign.center,
                style: TextStyle(color: subText, fontSize: 13),
              ),
              const SizedBox(height: 5),
              Text(
                email.isEmpty ? "your email address" : email,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: dialogText),
              ),
              const SizedBox(height: 20),

              // 6-Digit Code Input UI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Container(
                    width: 35,
                    height: 45,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                      color: boxColor,
                    ),
                    child: Center(
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dialogText),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: "",
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                "Note: Standard Firebase sends a link, not a code.\nThis UI is for demonstration.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.red[300], fontStyle: FontStyle.italic),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (email.isNotEmpty) {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Reset link sent to your email!")));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C97FA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Verify", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showDialog(String title, String content) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    // 1. Detect Dark Mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 2. Define Colors based on mode
    final bgColor = const Color(0xFF2C97FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Section
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Icon(Icons.medical_services_outlined, color: Colors.white, size: 50),
                  const SizedBox(height: 10),
                  const Text("Sign In Account",
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 5),
                  Text("Sign in to continue to E-Clinic",
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),

            // Bottom Card
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Welcome Back",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                        const SizedBox(height: 30),

                        // Email Field
                        _buildLabel("Email", textColor),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          style: TextStyle(color: textColor),
                          decoration:
                          _inputDecoration("demo@gmail.com", isDarkMode),
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        _buildLabel("Password", textColor),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration("Password", isDarkMode).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                        ),

                        const SizedBox(height: 15),

                        // Remember Me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: bgColor,
                                      side: BorderSide(
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.grey),
                                      onChanged: (val) => setState(() => _rememberMe = val!)),
                                ),
                                const SizedBox(width: 8),
                                Text("Remember me",
                                    style: TextStyle(color: subTextColor)),
                              ],
                            ),
                            TextButton(
                              onPressed: () => _showForgotPasswordDialog(isDarkMode),
                              child: Text("Forgot Password?",
                                  style: TextStyle(color: subTextColor)),
                            )
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onLoginPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bgColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("SIGN IN",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // --- OR DIVIDER ---
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text("OR", style: TextStyle(color: subTextColor)),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // --- GOOGLE BUTTON ---
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.redAccent),
                            label: Text(
                              "Continue with Google",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor),
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("If you have no account in here ",
                                style: TextStyle(color: subTextColor)),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
                              child: Text("Sign Up",
                                  style: TextStyle(
                                      color: bgColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildLabel(String text, Color color) {
    return Text(text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color));
  }

  InputDecoration _inputDecoration(String hint, bool isDarkMode) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      filled: true,
      fillColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F6FA),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C97FA), width: 1.5)),
    );
  }
}