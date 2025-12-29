import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadFromPrefs();
  }

  // 1. Load Theme from Local Storage on App Start
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  // 2. Toggle Theme (Called from Switch)
  Future<void> toggleTheme(bool isOn) async {
    _isDarkMode = isOn;
    notifyListeners(); // This updates the entire app immediately!

    // Save to Local Storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isOn);

    // Save to Firebase (Sync across devices)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isDarkMode': isOn,
        });
      }
    } catch (e) {
      print("Error saving theme to Firestore: $e");
    }
  }
}