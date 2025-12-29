// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:e_clinic_new/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/patient_home.dart';
import 'screens/doctor_home.dart';
import 'screens/doctor_form_screen.dart';
import 'screens/doctor_detail.dart';
import 'screens/book_appointment.dart';
import 'screens/appointments_list.dart';
import 'screens/patient_profile_screen.dart';
import 'screens/patient_history_screen.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const EClinicApp(),
    ),
  );
}

class EClinicApp extends StatelessWidget {
  const EClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'E-Clinic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: const Color(0xFF1E1E1E),
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/patient_home': (_) => const PatientHomeScreen(),
        '/doctor_home': (_) => const DoctorHomeScreen(),
        '/doctor_form': (context) => const DoctorProfileFormScreen(),
        '/doctor_detail': (context) => const DoctorDetailScreen(),
        '/book_appointment': (context) => const BookAppointmentScreen(),
        '/appointments_list': (context) => const AppointmentsList(),
        '/profile': (_) => const PatientProfileScreen(),
        '/history': (_) => const PatientHistoryScreen(),
        '/chat_screen': (context) => const ChatScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String? _errorMessage;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Scale Animation (Bounce effect)
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Fade Animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward(); // Start Animation

    _decideNavigation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _decideNavigation() async {
    try {
      // Wait a bit longer so user can see the animation
      await Future.delayed(const Duration(milliseconds: 2000));
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('uid');
        await prefs.remove('role');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final uid = user.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/signup');
        return;
      }

      final data = doc.data()!;
      final role = (data['role'] ?? 'patient').toString();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', uid);
      await prefs.setString('role', role);
      if (data['name'] != null) await prefs.setString('name', data['name'].toString());

      if (!mounted) return;
      if (role == 'patient') {
        Navigator.pushReplacementNamed(context, '/patient_home');
      } else if (role == 'doctor') {
        if (data['isProfileCompleted'] && data['approved']) {
          Navigator.pushReplacementNamed(context, '/doctor_home');
        } else {
          Navigator.pushReplacementNamed(context, '/doctor_form');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = 'Firebase error: ${e.message ?? e.code}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)], // Modern Purple-Blue Gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centered Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ]
                    ),
                    child: const Icon(Icons.medical_services_rounded, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                // Animated Text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'E-Clinic',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connecting patients & doctors',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Loader & Error Msg
            Positioned(
              bottom: 50,
              child: Column(
                children: [
                  if (_errorMessage == null)
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    )
                  else ...[
                    Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _decideNavigation();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}