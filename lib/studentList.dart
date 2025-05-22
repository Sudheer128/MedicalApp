import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:medicalapp/college_student_form.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String degree;
  final String courseName;

  const CourseDetailsScreen({
    Key? key,
    required this.degree,
    required this.courseName,
  }) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  List<dynamic> students = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    final url = Uri.parse(
      'http://192.168.0.103:8080/students-by-course',
    ).replace(
      queryParameters: {
        'degree': widget.degree,
        'course': widget.courseName == 'MBBS' ? ' ' : widget.courseName,
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = jsonDecode(response.body);
        setState(() {
          students = jsonResponse;
          isLoading = false;
          error = null;
        });
      } else {
        setState(() {
          error = 'Failed to load students: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching students: $e';
        isLoading = false;
      });
    }
  }

  Widget buildStudentCard(BuildContext context, Map<String, dynamic> student) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final applicationId = student['application'];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentDetailScreen(applicationId: applicationId),
          ),
        );
      },
      child: StudentCard(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} Details'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text(error!))
              : LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 600;
                  // breakpoint for mobile vs web/tablet layout

                  if (kIsWeb || isWideScreen) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children:
                            students.map((student) {
                              return SizedBox(
                                width: 450,
                                child: buildStudentCard(context, student),
                              );
                            }).toList(),
                      ),
                    );
                  } else {
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: buildStudentCard(context, students[index]),
                        );
                      },
                    );
                  }
                },
              ),
    );
  }
}

class StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const StudentCard({Key? key, required this.student}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final highestDegree = student['highest_degree'] ?? {};
    final latestExperience = student['latest_experience'] ?? {};

    final degree = highestDegree['degree'] ?? '-';
    final degreeStart = highestDegree['start_date'] ?? '-';
    final degreeEnd = highestDegree['end_date'] ?? '-';

    final hospital = latestExperience['hospital_name'] ?? '-';
    final expFrom = latestExperience['from_date'] ?? '-';
    final expTo = latestExperience['to_date'] ?? '-';
    final role = latestExperience['role'] ?? '';

    final experienceText =
        role.isEmpty ? 'No experience' : '$hospital ($expFrom to $expTo)';

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.deepPurple.shade100,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Name: ${student['name']}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade900,
                shadows: [
                  Shadow(
                    color: Colors.deepPurple.shade200,
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.deepPurple.shade800,
                ),
                children: [
                  const TextSpan(
                    text: 'Highest Degree: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$degree ($degreeStart to $degreeEnd)'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.deepPurple.shade800,
                ),
                children: [
                  const TextSpan(
                    text: 'Experience: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: experienceText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
