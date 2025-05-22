import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  Widget buildEducation(List<dynamic> educationList) {
    if (educationList.isEmpty)
      return Text('No education details', style: TextStyle(fontSize: 14));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  'Degree',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Course',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'College',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Duration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Divider(),
        // Data rows
        ...educationList.map((edu) {
          final degree = edu['Degree'] ?? '-';
          final courseName =
              (edu['CourseName'] ?? '').isEmpty ? '-' : edu['CourseName'];
          final college = edu['College'] ?? '-';
          final from = edu['YearFrom'] ?? '-';
          final to = edu['YearTo'] ?? '-';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(degree)),
                Expanded(flex: 3, child: Text(courseName)),
                Expanded(flex: 3, child: Text(college)),
                Expanded(flex: 2, child: Text('$from to $to')),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget buildExperience(List<dynamic>? experienceList) {
    if (experienceList == null || experienceList.isEmpty) {
      return Text('No experience', style: TextStyle(fontSize: 14));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  'Role',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Hospital',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Place',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Duration',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Divider(),
        ...experienceList.map((exp) {
          final role = exp['Title'] ?? '-';
          final hospital = exp['Hospital'] ?? '-';
          final place = exp['Location'] ?? '-';
          final from = exp['FromYear'] ?? '-';
          final to = exp['ToYear'] ?? '-';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(role)),
                Expanded(flex: 3, child: Text(hospital)),
                Expanded(flex: 3, child: Text(place)),
                Expanded(flex: 2, child: Text('$from to $to')),
              ],
            ),
          );
        }).toList(),
      ],
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
              ? Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text(error!))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Name: ${student['name']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Education:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          buildEducation(student['education_details'] ?? []),
                          const SizedBox(height: 12),
                          const Text(
                            'Experience:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          buildExperience(student['experience']),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
