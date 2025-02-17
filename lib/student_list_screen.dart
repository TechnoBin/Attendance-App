import 'package:attendance_app/student_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentListScreen extends StatefulWidget {
  final String className;

  StudentListScreen({required this.className});

  @override
  _StudentListScreenState createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<String> allStudents = [];
  List<String> presentStudents = [];
  List<String> absentStudents = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAttendance();
  }

  void _loadAttendance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedStudents = prefs.getStringList(widget.className) ?? [];
    //List<String> attendanceList = prefs.getStringList("attendanceList") ?? [];
    List<String> presentStudents = prefs.getStringList("") ?? [];

    setState(() {
      allStudents = savedStudents;
      this.presentStudents = presentStudents;
      absentStudents =
          savedStudents.where((s) => !presentStudents.contains(s)).toList();
      // presentStudents = allStudents
      //     .where((student) => attendanceList.contains(student))
      //     .toList();

      // absentStudents = allStudents
      //     .where((student) => !attendanceList.contains(student))
      //     .toList();
    });
  }

  void _deleteStudent(String student) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedStudents = prefs.getStringList(widget.className) ?? [];

    savedStudents.remove(student); // Remove student from list
    await prefs.setStringList(widget.className, savedStudents);
    // List<String> attendanceList = prefs.getStringList("attendanceList") ?? [];
    // attendanceList.remove(student);
    // await prefs.setStringList("attendanceList", attendanceList);

    // Update storage

    setState(() {
      allStudents = savedStudents; // Refresh list
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$student removed!"), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // 3 Tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text("Class ${widget.className} - Students"),
          actions: [
            IconButton(
                onPressed: () {
                  setState(() {
                    _loadAttendance();
                  });
                },
                icon: Icon(Icons.refresh))
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: "Total"),
              Tab(text: "Present"),
              Tab(text: "Absent"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStudentList(allStudents, "Total Students"),
            _buildStudentList(presentStudents, "Present Students",
                color: Colors.green),
            _buildStudentList(absentStudents, "Absent Students",
                color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList(List<String> students, String title,
      {Color color = Colors.black}) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$title: ${students.length}",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 10),
          Expanded(
            child: students.isEmpty
                ? Center(
                    child: Text("No students found",
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      String studentEntry = students[index];
                      String studentName = studentEntry.split(", ")[0];

                      return GestureDetector(
                        onTap: () {
                          List<String> studentData =
                              students[index].split(", Roll No: ");
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentDetailScreen(
                                  name: studentData[0],
                                  rollNo: studentData.length > 1
                                      ? studentData[1]
                                      : "N/A",
                                  studentClass: widget.className,
                                ),
                              ));
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text("Delete Student"),
                                content: Text(
                                    "Are you sure you want to remove ${allStudents[index]}?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _deleteStudent(allStudents[index]);
                                      Navigator.pop(context); // Close dialog
                                    },
                                    child: Text("Delete",
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: ListTile(
                          title: Text(studentName),
                          leading: Icon(
                            color == Colors.green
                                ? Icons.check_circle
                                : (color == Colors.red
                                    ? Icons.cancel
                                    : Icons.person),
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
