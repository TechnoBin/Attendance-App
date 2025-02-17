import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/success_screen.dart';

class AddNewStudentScreen extends StatefulWidget {
  @override
  _AddNewStudentScreenState createState() => _AddNewStudentScreenState();
}

class _AddNewStudentScreenState extends State<AddNewStudentScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController rollNoController = TextEditingController();
  final TextEditingController classController = TextEditingController();

  void _addStudent() async {
    if (nameController.text.isNotEmpty &&
        rollNoController.text.isNotEmpty &&
        classController.text.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Get existing students for the class
      List<String> students = prefs.getStringList(classController.text) ?? [];

      // Add new student
      students.add("${nameController.text}, Roll No: ${rollNoController.text}");

      // Save back to storage
      await prefs.setStringList(classController.text, students);

      // Navigate to Success Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessScreen(
            name: nameController.text,
            rollNo: rollNoController.text,
            studentClass: classController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add New Student")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Student Name"),
            ),
            TextField(
              controller: rollNoController,
              decoration: InputDecoration(labelText: "Roll No."),
            ),
            TextField(
              controller: classController,
              decoration: InputDecoration(labelText: "Class"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addStudent,
              child: Text("Add Student"),
            ),
          ],
        ),
      ),
    );
  }
}
