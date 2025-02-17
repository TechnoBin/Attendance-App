import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  _ScanQRScreenState createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  List<String> attendanceList = [];
  String scannedData = "Scan a QR Code";

  void _loadAttendance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      attendanceList = prefs.getStringList('attendanceList') ?? [];
    });
  }

  void _markAttendance(String studentData, String studentClass) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // ✅ Get student list for this class
    List<String> savedStudents = prefs.getStringList(studentClass) ?? [];

    // ✅ Get present students in this class
    List<String> presentStudents =
        prefs.getStringList("present_$studentClass") ?? [];

    // ✅ Check if the scanned student exists in the class
    if (!savedStudents.contains(studentData)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Invalid QR Code! Student not found in $studentClass."),
          backgroundColor: Colors.red,
        ));
      }
      return; // Stop processing if the student is not in the class
    }

    // ✅ Mark the student as present only if they are not already marked
    if (!presentStudents.contains(studentData)) {
      presentStudents.add(studentData);
      await prefs.setStringList("present_$studentClass", presentStudents);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$studentData marked present!"),
          backgroundColor: Colors.green,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$studentData is already marked present."),
          backgroundColor: Colors.orange,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan QR Code")),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  String studentData =
                      barcodes.first.rawValue ?? "No Data found";
                  List<String> studentInfo = studentData.split(", Class: ");
                  if (studentInfo.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Invalid"),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }
                  String studentClass = studentInfo[1];
                  _markAttendance(studentData, studentClass);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text("Result: $scannedData",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
