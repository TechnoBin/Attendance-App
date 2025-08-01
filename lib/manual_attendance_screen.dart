import 'package:attendance_app_2/theme_notifier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ManualAttendanceScreen extends StatefulWidget {
  final String classId;
  final String className;
  final DateTime selectedDate;

  const ManualAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.selectedDate,
  });

  @override
  _ManualAttendanceScreenState createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  late String firestoreUserId;
  List<DocumentSnapshot> students = [];
  List<DocumentSnapshot> filteredStudents = [];
  Set<String> presentStudentIds = {}; // Track selected present students
  bool isLoading = true;
  bool isSaving = false;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    firestoreUserId = FirebaseAuth.instance.currentUser!.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    final studentsFuture =
        FirebaseFirestore.instance
            .collection('users')
            .doc(firestoreUserId)
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .get();

    final attendanceFuture =
        FirebaseFirestore.instance
            .collection('users')
            .doc(firestoreUserId)
            .collection('classes')
            .doc(widget.classId)
            .collection('attendance')
            .doc(dateKey)
            .get();

    final results = await Future.wait([studentsFuture, attendanceFuture]);
    final studentsSnapshot = results[0] as QuerySnapshot;
    final attendanceDoc = results[1] as DocumentSnapshot;

    Set<String> presentIds = {};
    if (attendanceDoc.exists && attendanceDoc.data() != null) {
      presentIds = Set<String>.from(attendanceDoc['present'] ?? []);
    }

    setState(() {
      students = studentsSnapshot.docs;
      presentStudentIds = presentIds;
      isLoading = false;
      _filterStudents();
    });
  }

  Future<void> _saveAttendance() async {
    setState(() => isSaving = true);

    String dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    var attendanceRef = FirebaseFirestore.instance
        .collection('users')
        .doc(firestoreUserId)
        .collection('classes')
        .doc(widget.classId)
        .collection('attendance')
        .doc(dateKey);

    try {
      await attendanceRef.set({'present': presentStudentIds.toList()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Attendance saved for ${widget.className}"),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save attendance: $e"),
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() => isSaving = false);
  }

    void _filterStudents() {
      filteredStudents =
          students.where((student) {
            final data = student.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();
    }
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);


    int totalStudents = filteredStudents.length;
    int presentCount = presentStudentIds.length;
    int absentCount = totalStudents - presentCount;

    return Scaffold(
      backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor:
            themeNotifier.isDarkMode ? Colors.blue.shade900 : Colors.blue,
        title: Text(
          "Mark Attendance - ${widget.className}",
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search students...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                          _filterStudents();
                        });
                      },
                    ),
                  ),

                  // Sticky summary + select all buttons
                  Material(
                    elevation: 4,
                    color:
                        themeNotifier.isDarkMode
                            ? Colors.grey.shade900
                            : Colors.blue.shade100,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                'Total: $totalStudents',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color:
                                      themeNotifier.isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                ),
                              ),
                              Text(
                                'Present: $presentCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'Absent: $absentCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    presentStudentIds =
                                        filteredStudents
                                            .map((s) => s.id)
                                            .toSet();
                                  });
                                },
                                child: const Text("Mark All Present"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    presentStudentIds.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade500,
                                ),
                                child: const Text("Mark All Absent"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Student list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        var studentData =
                            filteredStudents[index].data()
                                as Map<String, dynamic>;
                        String studentId = filteredStudents[index].id;
                        String studentName = studentData['name'] ?? 'Unknown';

                        bool isPresent = presentStudentIds.contains(studentId);

                        return Semantics(
                          label:
                              '$studentName, ${isPresent ? 'present' : 'absent'}',
                          toggled: isPresent,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isPresent
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isPresent
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                studentName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isPresent
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                ),
                              ),
                              value: isPresent,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    presentStudentIds.add(studentId);
                                  } else {
                                    presentStudentIds.remove(studentId);
                                  }
                                });
                              },
                              activeColor: Colors.green.shade700,
                              checkColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.leading,
                              // Enable semantic focus for screen readers
                              secondary: Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color:
                                    isPresent
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isSaving ? null : _saveAttendance,
        backgroundColor:
            isSaving
                ? Theme.of(context).primaryColor.withOpacity(0.6)
                : Theme.of(context).primaryColor,
        label:
            isSaving
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text('Save', style: TextStyle(color: Colors.white)),
        icon: isSaving ? null : const Icon(Icons.save, color: Colors.white),
        tooltip: 'Save Attendance',
      ),
    );
  }
}
