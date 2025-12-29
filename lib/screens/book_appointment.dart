import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  // Lists to manage slots
  List<String> _allSlots = [];      // All possible slots (e.g., 9am - 5pm)
  List<String> _bookedSlots = [];   // Slots already taken in DB
  List<String> _availableSlots = []; // The final list shown to user

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize slots only if empty
    if (_allSlots.isEmpty) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final String start = args['startTime'] ?? "09:00";
      final String end = args['endTime'] ?? "17:00";

      // 1. Generate all possible slots first
      _generateAllSlots(start, end);

      // 2. Then check which ones are taken for Today
      _fetchBookedSlots();
    }
  }

  // Generate the raw list of times (9:00, 9:30, ...)
  void _generateAllSlots(String startStr, String endStr) {
    int toMinutes(String time) {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    String formatTime(int totalMinutes) {
      int h = totalMinutes ~/ 60;
      int m = totalMinutes % 60;
      String period = h >= 12 ? "PM" : "AM";
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      String mStr = m.toString().padLeft(2, '0');
      return "$h:$m $period";
    }

    int current = toMinutes(startStr);
    int end = toMinutes(endStr);
    List<String> slots = [];

    while (current < end) {
      slots.add(formatTime(current));
      current += 60;
    }

    setState(() {
      _allSlots = slots;
      // Initially, assume all are available until we fetch booked ones
      _updateAvailableSlots();
    });
  }

  // Fetch taken slots from Firebase
  Future<void> _fetchBookedSlots() async {
    setState(() => _isLoading = true);

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String doctorId = args['doctorId'];

    // Create a simple date string ID (e.g., "2025-12-11")
    final String dateId = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('dateStr', isEqualTo: dateId)
          .get();

      List<String> taken = [];
      for (var doc in snapshot.docs) {
        taken.add(doc['time'] as String);
      }

      if (mounted) {
        setState(() {
          _bookedSlots = taken;
          _updateAvailableSlots(); // Recalculate available list
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error fetching slots: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Filter: Available = All - Booked
  void _updateAvailableSlots() {
    setState(() {
      _availableSlots = _allSlots.where((slot) => !_bookedSlots.contains(slot)).toList();

      // If the currently selected time just got removed (because we changed date), unselect it
      if (_selectedTime != null && !_availableSlots.contains(_selectedTime)) {
        _selectedTime = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time selection on date change
      });
      // Fetch new slots for the new date
      _fetchBookedSlots();
    }
  }

  Future<void> _confirmBooking(String doctorId, String doctorName) async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a time slot")));
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // --- FIX: Get Name from Local Storage ---
      final prefs = await SharedPreferences.getInstance();
      final String patientName = prefs.getString('name') ?? "Patient";

      // Helper for Date String
      final String dateId = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";

      // 1. Prepare Data
      final appointmentData = {
        'patientId': user.uid,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'date': Timestamp.fromDate(_selectedDate),
        'dateStr': dateId, // <--- NEW: Saving simple string for easy querying
        'time': _selectedTime,
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 2. Save to Firestore
      await FirebaseFirestore.instance.collection('appointments').add(appointmentData);

      if (!mounted) return;

      // 3. Safe Navigation (Prevent "Dark Screen" Crash)
      Navigator.of(context).pushNamedAndRemoveUntil('/patient_home', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Appointment Booked Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String doctorId = args['doctorId'];
    final String doctorName = args['doctorName'] ?? "Doctor";

    // Formatting date for display
    final dateStr = "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";

    return Scaffold(
      appBar: AppBar(title: const Text("Book Appointment")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Booking with Dr. $doctorName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 30),

            // Date Picker
            const Text("Select Date", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.blue.shade50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time Slots (Dynamic)
            const Text("Available Slots", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Show loading or empty states
            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : _availableSlots.isEmpty
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade50,
              child: const Text("Fully booked for this date.", textAlign: TextAlign.center, style: TextStyle(color: Colors.orange)),
            )
                : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableSlots.map((slot) {
                final isSelected = _selectedTime == slot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  selectedColor: Colors.blueAccent,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    setState(() => _selectedTime = selected ? slot : null);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Reason Input
            const Text("Reason", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Briefly describe your problem...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _confirmBooking(doctorId, doctorName),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Confirm Booking", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}