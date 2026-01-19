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
  // --- FIX 1: Default date is set to Tomorrow, not Today ---
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  String? _selectedTime;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  List<String> _allSlots = [];
  List<String> _bookedSlots = [];
  List<String> _availableSlots = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allSlots.isEmpty) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final String start = args['startTime'] ?? "09:00";
      final String end = args['endTime'] ?? "17:00";
      _generateAllSlots(start, end);
      _fetchBookedSlots();
    }
  }

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
      String hStr = h.toString().padLeft(2, '0');
      String mStr = m.toString().padLeft(2, '0');
      return "$hStr:$mStr $period";
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
      _updateAvailableSlots();
    });
  }

  Future<void> _fetchBookedSlots() async {
    setState(() => _isLoading = true);
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String doctorId = args['doctorId'];
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
          _updateAvailableSlots();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching slots: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateAvailableSlots() {
    setState(() {
      _availableSlots = _allSlots.where((slot) => !_bookedSlots.contains(slot)).toList();
      if (_selectedTime != null && !_availableSlots.contains(_selectedTime)) {
        _selectedTime = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // --- FIX 2: Restrict DatePicker to start from Tomorrow ---
    final tomorrow = now.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(tomorrow) ? tomorrow : _selectedDate,
      firstDate: tomorrow, // User cannot scroll back to today
      lastDate: now.add(const Duration(days: 30)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
      _fetchBookedSlots();
    }
  }

  // --- CHANGED: Instead of 'Confirm', we 'Proceed to Payment' ---
  Future<void> _proceedToPayment(String doctorId, String doctorName, String fees) async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a time slot")));
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason")));
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final prefs = await SharedPreferences.getInstance();
      final String patientName = prefs.getString('name') ?? "Patient";
      final String dateId = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";

      // 1. Prepare the Data (DO NOT SAVE TO FIRESTORE YET)
      final appointmentDetails = {
        'patientId': user.uid,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'date': _selectedDate.toIso8601String(), // Passing as String to avoid routing issues
        'dateStr': dateId,
        'time': _selectedTime,
        'reason': _reasonController.text.trim(),
        'fees': fees, // Pass fees for Stripe
        'status': 'pending',
      };

      // 2. Navigate to Payment Screen with this data
      Navigator.pushNamed(context, '/payment_screen', arguments: appointmentDetails);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- DARK MODE LOGIC ---
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final containerColor = isDarkMode ? Colors.grey[800] : Colors.blue.shade50;
    final warningContainerColor = isDarkMode ? Colors.brown[900] : Colors.orange.shade50;

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String doctorId = args['doctorId'];
    final String doctorName = args['doctorName'] ?? "Doctor";
    final String fees = args['fees'] ?? "0"; // Fetch fees passed from previous screen

    final dateStr = "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";

    return Scaffold(
      appBar: AppBar(title: const Text("Book Appointment")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Booking with Dr. $doctorName",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),

            // Show Fees
            Text("Consultation Fees: $fees PKR",
                style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold)),

            const Divider(height: 30),

            // Date Picker
            Text("Select Date (Tomorrow onwards)", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(10),
                    color: containerColor),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time Slots logic remains same...
            Text("Available Slots", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),

            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                : _availableSlots.isEmpty
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: warningContainerColor,
              child: const Text("Fully booked for this date.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange)),
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
                  labelStyle: TextStyle(color: isSelected ? Colors.white : textColor),
                  onSelected: (selected) {
                    setState(() => _selectedTime = selected ? slot : null);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Reason Input
            Text("Reason", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Briefly describe your problem...",
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDarkMode ? Colors.grey : Colors.black45)),
              ),
            ),
            const SizedBox(height: 40),

            // --- CHANGED: Button Text & Action ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _proceedToPayment(doctorId, doctorName, fees),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Proceed to Payment", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}