import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationController extends StatefulWidget {
  final Widget child;
  final bool isDoctor;

  const NotificationController({super.key, required this.child, required this.isDoctor});

  @override
  State<NotificationController> createState() => _NotificationControllerState();
}

class _NotificationControllerState extends State<NotificationController> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    if (widget.isDoctor) {
      _listenForDoctorEvents();
    } else {
      _listenForPatientEvents();
    }
  }

  // --- DOCTOR: Listen for New Requests & Ratings ---
  void _listenForDoctorEvents() {
    // 1. New Appointments (Status: Pending)
    FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleNotification(
            "New Appointment Request",
            "You have a new patient request.",
          );
        }
      }
    });

    // 2. New Ratings
    FirebaseFirestore.instance
        .collection('ratings')
        .where('doctorId', isEqualTo: _uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          // Fix: Ensure rating is treated as Number safely
          final rating = (data['rating'] ?? 0).toString();
          _handleNotification(
            "New Rating Received",
            "A patient gave you $rating stars.",
          );
        }
      }
    });
  }

  // --- PATIENT: Listen for Status Changes ---
  void _listenForPatientEvents() {
    FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: _uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // We only care if status CHANGED (Modified)
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          final status = data['status'];
          final doctorName = data['doctorName'] ?? "Doctor";

          if (status == 'confirmed') {
            _handleNotification(
                "Appointment Confirmed",
                "Dr. $doctorName has accepted your appointment."
            );
            _scheduleReminders(data); // Schedule 1 hour before
          } else if (status == 'cancelled') {
            _handleNotification(
                "Appointment Cancelled",
                "Dr. $doctorName cancelled the appointment."
            );
          } else if (status == 'completed') {
            _handleNotification(
                "Appointment Completed",
                "Your visit with Dr. $doctorName is complete. Please rate!"
            );
          }
        }
      }
    });
  }

  // --- HELPER: Schedule 1 Hour Before ---
  void _scheduleReminders(Map<String, dynamic> data) {
    try {
      if (data['date'] == null) return;

      // 1. Get Date (Timestamp)
      Timestamp ts = data['date'];
      DateTime appointmentTime = ts.toDate();

      // 2. Calculate 1 Hour Before
      final reminderTime = appointmentTime.subtract(const Duration(hours: 1));
      final dayReminder = appointmentTime.subtract(const Duration(days: 1));

      // 3. Schedule if in future
      if (reminderTime.isAfter(DateTime.now())) {
        NotificationService.scheduleNotification(
            id: data.hashCode,
            title: "Appointment Reminder",
            body: "You have an appointment in 1 hour with Dr. ${data['doctorName']}",
            scheduledTime: reminderTime
        );
      }

      if (dayReminder.isAfter(DateTime.now())) {
        NotificationService.scheduleNotification(
            id: data.hashCode + 1,
            title: "Appointment Tomorrow",
            body: "Don't forget your appointment tomorrow with Dr. ${data['doctorName']}",
            scheduledTime: dayReminder
        );
      }

    } catch (e) {
      debugPrint("Error scheduling reminder: $e");
    }
  }

  // --- CENTRAL HANDLER: Show Pop-up & Save to DB ---
  void _handleNotification(String title, String body) {
    // 1. Show Local Notification (Pop-up)
    NotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
    );

    // 2. Save to Firestore (For Notification Page)
    FirebaseFirestore.instance.collection('notifications').add({
      'userId': _uid,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}