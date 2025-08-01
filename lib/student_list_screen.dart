import 'dart:async';
import 'package:attendance_app_2/add_student_screen.dart';
import 'package:attendance_app_2/manual_attendance_screen.dart';
import 'package:attendance_app_2/student_detail_screen.dart';
import 'package:attendance_app_2/theme_notifier.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentListScreen extends StatefulWidget {
  final String classId;
  final String className;

  const StudentListScreen({
    super.key,
    required this.className,
    required this.classId,
    required userId,
  });

  @override
  _StudentListScreenState createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  DateTime selectedDate = DateTime.now();
  List<DocumentSnapshot> totalStudents = [];
  List<DocumentSnapshot> presentStudents = [];
  List<DocumentSnapshot> absentStudents = [];
  bool isLoading = false;
  bool isDownloading = false;
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  late String firestoreUserId;
  late StreamSubscription<QuerySnapshot> _studentsSubscription;
  late StreamSubscription<DocumentSnapshot> _attendanceSubscription;

  List<DocumentSnapshot> _latestStudents = [];
  List<String> _latestPresentIds = [];

  void _listenToStudentsAndAttendance() {
    final studentsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(firestoreUserId)
        .collection('classes')
        .doc(widget.classId)
        .collection('students');

    final attendanceRef = FirebaseFirestore.instance
        .collection('users')
        .doc(firestoreUserId)
        .collection('classes')
        .doc(widget.classId)
        .collection('attendance')
        .doc(DateFormat('yyyy-MM-dd').format(selectedDate));

    _studentsSubscription = studentsRef.snapshots().listen((studentsSnapshot) {
      _latestStudents = studentsSnapshot.docs;
      _combineAndSetState();
    });

    _attendanceSubscription = attendanceRef.snapshots().listen((
      attendanceSnapshot,
    ) {
      if (attendanceSnapshot.exists && attendanceSnapshot.data() != null) {
        _latestPresentIds = List<String>.from(
          attendanceSnapshot['present'] ?? [],
        );
      } else {
        _latestPresentIds = [];
      }
      _combineAndSetState();
    });
  }

  void _combineAndSetState() {
    List<DocumentSnapshot> present = [];
    List<DocumentSnapshot> absent = [];

    for (var student in _latestStudents) {
      if (_latestPresentIds.contains(student.id)) {
        present.add(student);
      } else {
        absent.add(student);
      }
    }

    setState(() {
      totalStudents = _latestStudents;
      presentStudents = present;
      absentStudents = absent;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _studentsSubscription.cancel();
    _attendanceSubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Since context is not ready here, consider showing error later or in build
      // For now, just print or handle gracefully
      print("User not logged in.");
      return;
    }
    firestoreUserId = user.uid;
    _listenToStudentsAndAttendance(); // Use real-time listeners instead of _fetchStudents()
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
        isLoading = true;
      });

      // Cancel previous attendance listener safely
      await _attendanceSubscription.cancel();

      final attendanceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(firestoreUserId)
          .collection('classes')
          .doc(widget.classId)
          .collection('attendance')
          .doc(DateFormat('yyyy-MM-dd').format(selectedDate));

      _attendanceSubscription = attendanceRef.snapshots().listen((
        attendanceSnapshot,
      ) {
        if (attendanceSnapshot.exists && attendanceSnapshot.data() != null) {
          _latestPresentIds = List<String>.from(
            attendanceSnapshot['present'] ?? [],
          );
        } else {
          _latestPresentIds = [];
        }
        _combineAndSetState();
      });
    }
  }

  void _confirmDownload() async {
    String? choice = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Download'),
            content: Text(
              'Download attendance record for class "${widget.className}" on ${DateFormat('dd MMM yyyy').format(selectedDate)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null), // cancel
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop('excel'),
                child: const Text('Download Excel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop('pdf'),
                child: const Text('Download PDF'),
              ),
            ],
          ),
    );

    if (choice == 'excel') {
      await _downloadAttendance(); // Your Excel download method
    } else if (choice == 'pdf') {
      await _downloadAttendancePdf(); // Your PDF download method
    }
  }

  Future<void> _downloadAttendance() async {
    try {
      setState(() {
        isDownloading = true;
      });

      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) {
            openAppSettings();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Manage External Storage permission is required to save CSV file.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            isDownloading = false;
          });
          return;
        }
      }

      var excel = Excel.createExcel();
      var sheet = excel['Sheet1'];

      int daysInMonth = DateUtils.getDaysInMonth(
        selectedDate.year,
        selectedDate.month,
      );
      List<String> header = ["Roll No", "Name"];

      for (int day = 1; day <= daysInMonth; day++) {
        header.add(day.toString()); // Display date as it is
      }
      header.add("Total Present Days");

      String title =
          'Class ${widget.className} - ${DateFormat('MMMM yyyy').format(selectedDate)}'; //Title
      var titleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      );
      titleCell.value = TextCellValue(title);
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: HorizontalAlign.Center,
      );

      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: header.length - 1, rowIndex: 0),
      );

      // Set headers
      for (int col = 0; col < header.length; col++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
        );
        cell.value = TextCellValue(header[col]);
        cell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          bold: true,
        );
      }

      // Adjust column width for Roll No and Name columns
      sheet.setColumnWidth(0, 10); // "Roll No" column width
      sheet.setColumnWidth(1, 20); // "Name" column width

      // Adjust column width for date columns (from column index 2 onward)
      for (int col = 2; col < header.length - 1; col++) {
        sheet.setColumnWidth(col, 5); // Set the width of the date columns to 5
      }

      sheet.setDefaultRowHeight(18.0); // Set a smaller row height

      int rowIndex = 2;
      for (var student in totalStudents) {
        var studentData = student.data() as Map<String, dynamic>? ?? {};
        String name = studentData['name'] ?? "Unknown";
        String rollNo = studentData['rollNo'] ?? "-";

        List<String> row = [rollNo, name];
        int totalPresentDays = 0;

        List<Future<DocumentSnapshot>> attendanceRequests = [];
        for (int day = 1; day <= daysInMonth; day++) {
          String dateKey =
              '${DateFormat('yyyy-MM').format(selectedDate)}-${day.toString().padLeft(2, '0')}';
          attendanceRequests.add(
            FirebaseFirestore.instance
                .collection('users')
                .doc(firestoreUserId)
                .collection('classes')
                .doc(widget.classId)
                .collection('attendance')
                .doc(dateKey)
                .get(),
          );
        }

        List<DocumentSnapshot> attendanceSnapshots = await Future.wait(
          attendanceRequests,
        );

        for (int day = 0; day < daysInMonth; day++) {
          var snapshot = attendanceSnapshots[day];
          String status = "-"; // Default status for missing attendance data

          // If it's a Sunday (weekend), mark the status as NSD
          if (DateTime(
                selectedDate.year,
                selectedDate.month,
                day + 1,
              ).weekday ==
              DateTime.sunday) {
            status = "SUN"; // Sunday is a Non-School Day
          } else if (snapshot.exists && snapshot.data() != null) {
            List<String> present = List<String>.from(snapshot['present'] ?? []);
            if (present.contains(student.id)) {
              status = "P";
              totalPresentDays++;
            } else {
              status = "A";
            }
          }

          row.add(status); // Add status to the row
        }

        row.add(totalPresentDays.toString());
        sheet.setColumnWidth(header.length - 1, 20);

        for (int col = 0; col < row.length; col++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          );
          cell.value = TextCellValue(row[col]);
          cell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
        }
        rowIndex++;
      }

      String downloadsPath =
          await ExternalPath.getExternalStoragePublicDirectory(
            ExternalPath.DIRECTORY_DOWNLOAD,
          );
      final directory = Directory('$downloadsPath/AttendanceApp');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      String fileName =
          'Attendance_Record_${widget.className}_${DateFormat('yyyy-MM').format(selectedDate)}.xlsx';
      String filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to encode Excel file.")),
        );
      }

      setState(() {
        isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: GestureDetector(
            onTap: () async {
              final file = File(filePath);
              if (await file.exists()) {
                OpenFile.open(filePath);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File not found.')),
                );
              }
            },
            child: Text('Excel file saved successfully at:\n$filePath'),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() {
        isDownloading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving Excel file: $e')));
    }
  }

  Future<void> _downloadAttendancePdf() async {
    try {
      setState(() {
        isDownloading = true;
      });

      final pdf = pw.Document();

      int daysInMonth = DateUtils.getDaysInMonth(
        selectedDate.year,
        selectedDate.month,
      );

      // Prepare header
      List<String> header = ["Roll No", "Name"];
      for (int day = 1; day <= daysInMonth; day++) {
        header.add(day.toString());
      }
      header.add("Total Present Days");

      // Step 1: Fetch all attendance documents in advance
      Map<String, List<String>> attendanceMap =
          {}; // dateKey -> list of present student IDs

      List<Future<void>> fetchAttendanceFutures = [];
      for (int day = 1; day <= daysInMonth; day++) {
        String dateKey =
            '${DateFormat('yyyy-MM').format(selectedDate)}-${day.toString().padLeft(2, '0')}';
        var future = FirebaseFirestore.instance
            .collection('users')
            .doc(firestoreUserId)
            .collection('classes')
            .doc(widget.classId)
            .collection('attendance')
            .doc(dateKey)
            .get()
            .then((doc) {
              if (doc.exists && doc.data() != null) {
                List<String> present = List<String>.from(doc['present'] ?? []);
                attendanceMap[dateKey] = present;
              } else {
                attendanceMap[dateKey] = [];
              }
            });
        fetchAttendanceFutures.add(future);
      }

      await Future.wait(fetchAttendanceFutures);

      // Title
      String title =
          'Class ${widget.className} - ${DateFormat('MMMM yyyy').format(selectedDate)}';

      // Step 2: Build PDF content with attendanceMap
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(16),
          build: (context) {
            return [
              pw.Center(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headers: header,
                data: List<List<String>>.generate(totalStudents.length, (
                  index,
                ) {
                  var student = totalStudents[index];
                  var studentData =
                      student.data() as Map<String, dynamic>? ?? {};
                  String name = studentData['name'] ?? "Unknown";
                  String rollNo = studentData['rollNo'] ?? "-";

                  List<String> row = [rollNo, name];
                  int totalPresentDays = 0;

                  for (int day = 1; day <= daysInMonth; day++) {
                    String dateKey =
                        '${DateFormat('yyyy-MM').format(selectedDate)}-${day.toString().padLeft(2, '0')}';

                    // Check if it's Sunday
                    if (DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          day,
                        ).weekday ==
                        DateTime.sunday) {
                      row.add("SUN");
                    } else {
                      List<String> presentStudents =
                          attendanceMap[dateKey] ?? [];
                      if (presentStudents.contains(student.id)) {
                        row.add("P");
                        totalPresentDays++;
                      } else {
                        row.add("A");
                      }
                    }
                  }
                  row.add(totalPresentDays.toString());

                  return row;
                }),
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(fontSize: 10),
              ),
            ];
          },
        ),
      );

      // Step 3: Save file to disk
      final bytes = await pdf.save();

      final downloadsPath =
          await ExternalPath.getExternalStoragePublicDirectory(
            ExternalPath.DIRECTORY_DOWNLOAD,
          );
      final directory = Directory('$downloadsPath/AttendanceApp');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath =
          '${directory.path}/Attendance_Record_${widget.className}_${DateFormat('yyyy-MM').format(selectedDate)}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      setState(() {
        isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: GestureDetector(
            onTap: () async {
              if (await file.exists()) {
                OpenFile.open(filePath);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File not found.')),
                );
              }
            },
            child: Text('PDF saved successfully at:\n$filePath'),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() {
        isDownloading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving PDF file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final iconColor =
        themeNotifier.isDarkMode ? Colors.white70 : Colors.black87;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: themeNotifier.isDarkMode ? Colors.black : Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverAppBar(
                floating: true,
                pinned: true,
                snap: false,
                backgroundColor:
                    themeNotifier.isDarkMode
                        ? Colors.blue.shade900
                        : Colors.blue,
                iconTheme: IconThemeData(color: iconColor),
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child:
                      isSearching
                          ? TextField(
                            key: const ValueKey('search'),
                            controller: searchController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: "Search by name or roll no...",
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                            style: const TextStyle(color: Colors.white),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value.toLowerCase();
                              });
                            },
                          )
                          : Text(
                            "Class ${widget.className}",
                            key: const ValueKey('title'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      isSearching ? Icons.close : Icons.search,
                      color: iconColor,
                    ),
                    tooltip: "Search Students",
                    onPressed: () {
                      setState(() {
                        if (isSearching) {
                          searchQuery = "";
                          searchController.clear();
                        }
                        isSearching = !isSearching;
                      });
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'calendar':
                          _selectDate(context);
                          break;
                        case 'download':
                          _confirmDownload();
                          break;
                        case 'markAttendance':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ManualAttendanceScreen(
                                    classId: widget.classId,
                                    className: widget.className,
                                    selectedDate: selectedDate,
                                  ),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder:
                        (BuildContext context) => [
                          _buildPopupMenuItem(
                            Icons.calendar_today,
                            'Select Date',
                            'calendar',
                          ),
                          _buildPopupMenuItem(
                            Icons.download,
                            'Download Attendance',
                            'download',
                          ),
                          _buildPopupMenuItem(
                            Icons.edit,
                            'Mark Attendance Manually',
                            'markAttendance',
                          ),
                        ],
                  ),
                ],
                bottom: TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      themeNotifier.isDarkMode
                          ? Colors.grey[500]
                          : Colors.grey[300],
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: "Total (${totalStudents.length})"),
                    Tab(text: "Present (${presentStudents.length})"),
                    Tab(text: "Absent (${absentStudents.length})"),
                  ],
                ),
              ),
            ];
          },
          body: Stack(
            children: [
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          "Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildStudentList(totalStudents),
                            _buildStudentList(presentStudents),
                            _buildStudentList(absentStudents),
                          ],
                        ),
                      ),
                    ],
                  ),
              if (isDownloading)
                Container(
                  color:
                      themeNotifier.isDarkMode
                          ? Colors.black87
                          : Colors.white70,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Downloading...', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Helper for popup menu items
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blue,
          tooltip: "Add New Student to this Class",
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AddNewStudentScreen(
                      firestoreUserId: firestoreUserId,
                      prefilledClassName: widget.className,
                    ),
              ),
            ).then((_) {});
          },
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    IconData icon,
    String text,
    String value,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [Icon(icon), const SizedBox(width: 10), Text(text)]),
    );
  }

  Widget _buildStudentList(List<DocumentSnapshot> students) {
    List<DocumentSnapshot> filtered =
        students.where((student) {
          final data = student.data() as Map<String, dynamic>? ?? {};
          final name = (data['name'] ?? "").toString().toLowerCase();
          final rollNo = (data['rollNo'] ?? "").toString().toLowerCase();
          return name.contains(searchQuery) || rollNo.contains(searchQuery);
        }).toList();

    int compareRollNumbers(String r1, String r2) {
      final regex = RegExp(r'^([a-zA-Z]*)(\d+)$');

      final match1 = regex.firstMatch(r1);
      final match2 = regex.firstMatch(r2);

      if (match1 == null || match2 == null) {
        // Fallback: if pattern doesn't match, do string compare
        return r1.compareTo(r2);
      }

      final prefix1 = match1.group(1) ?? '';
      final prefix2 = match2.group(1) ?? '';

      final num1 = int.tryParse(match1.group(2) ?? '') ?? 0;
      final num2 = int.tryParse(match2.group(2) ?? '') ?? 0;

      final prefixCompare = prefix1.compareTo(prefix2);
      if (prefixCompare != 0) {
        return prefixCompare;
      }
      return num1.compareTo(num2);
    }

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>? ?? {};
      final bData = b.data() as Map<String, dynamic>? ?? {};

      final aRoll = (aData['rollNo'] ?? '').toString().toLowerCase();
      final bRoll = (bData['rollNo'] ?? '').toString().toLowerCase();

      return compareRollNumbers(aRoll, bRoll);
    });

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          "No students found.",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 0),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        var studentData = filtered[index].data() as Map<String, dynamic>? ?? {};
        String studentId = filtered[index].id;

        return Tooltip(
          message: 'Tap to view details\nLong press to delete',
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const CircleAvatar(
                radius: 23,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                studentData['name'] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Roll No: ${studentData['rollNo']}'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => StudentDetailScreen(
                          studentData: studentData,
                          firestoreUserId: firestoreUserId,
                        ),
                  ),
                );
              },
              onLongPress: () {
                _showDeleteConfirmationDialog(context, studentId);
              },
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String studentId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Student"),
          content: const Text("Are you sure you want to delete this student?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteStudent(studentId);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStudent(String studentId) async {
    try {
      var studentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(firestoreUserId)
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(studentId);

      await studentRef.delete();

      setState(() {
        totalStudents.removeWhere((student) => student.id == studentId);
        presentStudents.removeWhere((student) => student.id == studentId);
        absentStudents.removeWhere((student) => student.id == studentId);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting student: $e")));
    }
  }
}
