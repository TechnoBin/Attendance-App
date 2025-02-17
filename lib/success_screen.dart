import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

class SuccessScreen extends StatelessWidget {
  final String name;
  final String rollNo;
  final String studentClass;

  SuccessScreen(
      {required this.name, required this.rollNo, required this.studentClass});

  void _saveQRCode(String studentName, String qrData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //await prefs.setString("qr_$studentname", qrData);
    Map<String, String> qrCodes = {};
    String? storedQRData = prefs.getString("qr_codes");
    if (storedQRData != null) {
      qrCodes = Map<String, String>.from(await jsonDecode(storedQRData));
    }
    qrCodes[studentName] = qrData;
    await prefs.setString("qr_codes", jsonEncode(qrCodes));
  }

  @override
  Widget build(BuildContext context) {
    String qrData = "Name: $name, Roll No: $rollNo, Class: $studentClass";
    _saveQRCode(name, qrData);

    return Scaffold(
      appBar: AppBar(title: Text("Student Added")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Successfully Added!",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              SizedBox(height: 20),

              // QR Code
              QrImageView(
                data: qrData,
                size: 200,
                backgroundColor: Colors.white,
              ),
              SizedBox(height: 20),

              // Student Details
              Text("Name: $name", style: TextStyle(fontSize: 18)),
              Text("Roll No: $rollNo", style: TextStyle(fontSize: 18)),
              Text("Class: $studentClass", style: TextStyle(fontSize: 18)),

              SizedBox(height: 30),

              // Done Button
              ElevatedButton(
                onPressed: () {
                  //Navigator.pop(context);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: Text("Done"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
