// main.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:medicalapp/college_student_form.dart';
import 'package:medicalapp/college_view.dart';
import 'package:medicalapp/edit_formAfterSave.dart';

class EditApplicationForm extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const EditApplicationForm({Key? key, this.existingData}) : super(key: key);

  @override
  State<EditApplicationForm> createState() => _EditApplicationFormState();
}

class _EditApplicationFormState extends State<EditApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = true;

  final GlobalKey _educationKey = GlobalKey();
  final GlobalKey _fellowshipKey = GlobalKey();
  final GlobalKey _papersKey = GlobalKey();
  final GlobalKey _workKey = GlobalKey();
  final GlobalKey _certificateKey = GlobalKey();
  final GlobalKey _resumeKey = GlobalKey();

  bool _hasPG = false;
  bool _hasSS = false;
  bool _hasFellowships = false;
  bool _hasPapers = false;
  bool _hasWorkExperience = false;

  List<Course> pgCourses = [];
  List<Course> ssCourses = [];

  bool isLoadingCourses = false;
  String? coursesError;

  // Separate lists for PG and SS details
  List<EducationDetail> pgDetails = [];
  List<EducationDetail> ssDetails = [];

  // Scroll & Keys for Drawer navigation
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _personalKey = GlobalKey();

  // Personal Details
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  // Education Details
  List<EducationDetail> educationDetails = [EducationDetail(type: 'MBBS')];

  // Fellowships
  List<Fellowship> fellowships = [Fellowship()];

  // Papers
  List<Paper> papers = [Paper()];

  // Work Experience
  List<WorkExperience> workExperiences = [WorkExperience()];

  // Medical Course Certificate
  final _counselNameController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _validityFromController = TextEditingController();
  final _validityToController = TextEditingController();
  final _registrationNumberController = TextEditingController();

  // Resume Upload
  File? _resumeFile;
  String? _resumeFileName;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _counselNameController.dispose();
    _courseNameController.dispose();
    _validityFromController.dispose();
    _validityToController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchCourses().then((_) {
      if (widget.existingData != null) {
        _populateFormWithExistingData(widget.existingData!);
      }
    });
  }

  void _populateFormWithExistingData(Map<String, dynamic> data) {
    // Personal details
    _nameController.text = data['name'] ?? '';
    _phoneController.text = (data['phone'] ?? '').toString();
    _emailController.text = data['email'] ?? '';
    _addressController.text = data['address'] ?? '';

    // Clear existing lists before populating
    educationDetails.clear();
    pgDetails.clear();
    ssDetails.clear();

    List<dynamic> educations = data['education'] ?? [];

    for (var edu in educations) {
      final type = edu['type'] ?? 'MBBS';
      final ed = EducationDetail(type: type);
      ed.courseName = edu['courseName'] ?? '';
      ed.collegeName = edu['collegeName'] ?? '';
      ed.fromDateController.text = _formatDateForController(edu['fromDate']);
      ed.toDateController.text = _formatDateForController(edu['toDate']);

      if (type == 'MBBS') {
        educationDetails.add(ed);
      } else if (type == 'PG') {
        pgDetails.add(ed);
        _hasPG = true;
      } else if (type == 'SS') {
        ssDetails.add(ed);
        _hasSS = true;
      }
    }

    // Fellowships
    fellowships.clear();
    List<dynamic> fellows = data['fellowships'] ?? [];
    _hasFellowships = fellows.isNotEmpty;
    for (var f in fellows) {
      final fellowship = Fellowship();
      fellowship.courseName = f['courseName'] ?? '';
      fellowship.collegeName = f['collegeName'] ?? '';
      fellowship.fromDateController.text = _formatDateForController(
        f['fromDate'],
      );
      fellowship.toDateController.text = _formatDateForController(f['toDate']);
      fellowships.add(fellowship);
    }

    // Papers
    papers.clear();
    List<dynamic> papersData = data['papers'] ?? [];
    _hasPapers = papersData.isNotEmpty;
    for (var p in papersData) {
      final paper = Paper();
      paper.name = p['name'] ?? '';
      paper.description = p['description'] ?? '';
      paper.submittedDateController.text = _formatDateForController(
        p['submittedOn'],
      );
      papers.add(paper);
    }

    // Work Experience
    workExperiences.clear();
    List<dynamic> workData = data['workExperiences'] ?? [];
    _hasWorkExperience = workData.isNotEmpty;
    for (var w in workData) {
      final work = WorkExperience();
      work.role = w['role'] ?? '';
      work.name = w['name'] ?? '';
      work.fromDateController.text = _formatDateForController(w['from']);
      work.toDateController.text = _formatDateForController(w['to']);
      work.place = w['place'] ?? '';
      work.description = w['description'] ?? '';
      workExperiences.add(work);
    }

    // Certificate
    final cert = data['certificate'] ?? {};
    _counselNameController.text = cert['counselName'] ?? '';
    _courseNameController.text = cert['courseName'] ?? '';
    _validityFromController.text = _formatDateForController(cert['validFrom']);
    _validityToController.text = _formatDateForController(cert['validTo']);
    _registrationNumberController.text = cert['registrationNumber'] ?? '';

    setState(() {
      _isEditing = true; // open form in edit mode
    });
  }

  String _formatDateForController(String? backendDate) {
    if (backendDate == null || backendDate.isEmpty) return '';
    try {
      final date = DateTime.parse(backendDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return backendDate;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _pickResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _resumeFile = File(result.files.single.path!);
        _resumeFileName = result.files.single.name;
      });
    }
  }

  void _toggleEditing(String section) {
    setState(() {
      if (section == 'all') {
        _isEditing = !_isEditing;
      } else {
        // handle per‐section if needed
        _isEditing = true;
      }
    });
  }

  void _saveForm() {
    final isValid = _formKey.currentState!.validate();

    if (!isValid) {
      // Instead of checking all sections and scrolling multiple times,
      // check in order and scroll to the first invalid section and return immediately.

      if (_personalKey.currentContext != null &&
          _hasErrorInSection(_personalKey)) {
        _scrollToSection(_personalKey);
        return;
      }

      if (_educationKey.currentContext != null &&
          _hasErrorInSection(_educationKey)) {
        _scrollToSection(_educationKey);
        return;
      }

      if (_hasFellowships &&
          _fellowshipKey.currentContext != null &&
          _hasErrorInSection(_fellowshipKey)) {
        _scrollToSection(_fellowshipKey);
        return;
      }

      if (_hasPapers &&
          _papersKey.currentContext != null &&
          _hasErrorInSection(_papersKey)) {
        _scrollToSection(_papersKey);
        return;
      }

      if (_hasWorkExperience &&
          _workKey.currentContext != null &&
          _hasErrorInSection(_workKey)) {
        _scrollToSection(_workKey);
        return;
      }

      if (_certificateKey.currentContext != null &&
          _hasErrorInSection(_certificateKey)) {
        _scrollToSection(_certificateKey);
        return;
      }

      return;
    }

    // If all valid
    _formKey.currentState!.save();
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Form saved successfully!')));
    _submitToBackend();
  }

  bool _hasErrorInSection(GlobalKey key) {
    bool hasError = false;
    void visitor(Element element) {
      if (element.widget is FormField) {
        final FormFieldState fieldState =
            (element as StatefulElement).state as FormFieldState;
        if (!fieldState.isValid) {
          hasError = true;
        }
      }
      element.visitChildren(visitor);
    }

    key.currentContext?.visitChildElements(visitor);
    return hasError;
  }

  void _scrollToSection(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  Future<void> fetchCourses() async {
    setState(() {
      isLoadingCourses = true;
      coursesError = null;
    });

    final uri = Uri.parse('http://192.168.0.103:8080/courses');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<Course> extractCourses(List<dynamic> coursesList) {
          return coursesList
              .where(
                (item) =>
                    item is Map &&
                    item['course_name'] != null &&
                    item['course_name'].toString().trim().isNotEmpty &&
                    item['duration'] != null,
              )
              .map<Course>(
                (item) => Course(
                  name: item['course_name'].toString(),
                  duration: double.tryParse(item['duration'].toString()) ?? 0,
                ),
              )
              .toList();
        }

        setState(() {
          pgCourses = extractCourses(data['pg'] ?? []);
          ssCourses = extractCourses(data['ss'] ?? []);
          isLoadingCourses = false;
        });
      } else {
        setState(() {
          coursesError = 'Failed to load courses: ${response.statusCode}';
          isLoadingCourses = false;
        });
      }
    } catch (e) {
      setState(() {
        coursesError = 'Error loading courses: $e';
        isLoadingCourses = false;
      });
    }
  }

  Future<void> _submitToBackend() async {
    final payload = {
      // Personal
      'name': _nameController.text,
      'phone': int.tryParse(_phoneController.text) ?? 0,
      'email': _emailController.text,
      'address': _addressController.text,

      // Education
      'education': [
        ...educationDetails.map((e) => e.toJson()),
        if (_hasPG) ...pgDetails.map((e) => e.toJson()) else ...[],
        if (_hasSS) ...ssDetails.map((e) => e.toJson()) else ...[],
      ],

      // Fellowships, Papers, Work Experience - pass empty lists if "No"
      'fellowships':
          _hasFellowships
              ? fellowships.map((f) => f.toJson()).toList()
              : <dynamic>[],
      'papers':
          _hasPapers ? papers.map((p) => p.toJson()).toList() : <dynamic>[],
      'workExperiences':
          _hasWorkExperience
              ? workExperiences.map((w) => w.toJson()).toList()
              : <dynamic>[],

      // Certificate
      'certificate': {
        'counselName': _counselNameController.text,
        'courseName': _courseNameController.text,
        'validFrom': convertDateToBackendFormat(_validityFromController.text),
        'validTo': convertDateToBackendFormat(_validityToController.text),
        'registrationNumber': _registrationNumberController.text,
      },
    };

    print(payload);

    final uri = Uri.parse('http://192.168.0.103:8080/counsel');
    late http.Response response;

    // If you have a resume file, send as multipart:
    if (_resumeFile != null) {
      final req =
          http.MultipartRequest('POST', uri)
            ..fields['data'] = jsonEncode(payload)
            ..files.add(
              await http.MultipartFile.fromPath(
                'resume',
                _resumeFile!.path,
                filename: _resumeFileName,
              ),
            );
      final streamed = await req.send();
      response = await http.Response.fromStream(streamed);
    } else {
      response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    }

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted successfully!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: ${response.statusCode}')),
      );
    }
  }

  Future<String?> _showSearchableCourseDialog(
    List<Course> courses,
    String? selectedCourse,
  ) async {
    TextEditingController searchController = TextEditingController();
    List<Course> filteredCourses = List.from(courses);

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void filterCourses(String query) {
              final filtered =
                  courses
                      .where(
                        (course) => course.name.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList();
              setStateDialog(() {
                filteredCourses = filtered;
              });
            }

            return AlertDialog(
              title: const Text('Select Course'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search courses',
                    ),
                    onChanged: filterCourses,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child:
                        filteredCourses.isEmpty
                            ? const Center(child: Text('No courses found'))
                            : ListView.builder(
                              itemCount: filteredCourses.length,
                              itemBuilder: (context, index) {
                                final course = filteredCourses[index];
                                return ListTile(
                                  title: Text(course.name),
                                  selected: course.name == selectedCourse,
                                  onTap:
                                      () => Navigator.pop(context, course.name),
                                );
                              },
                            ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double getSelectedCourseDuration(EducationDetail education) {
    if (education.type == 'MBBS') {
      return 5.5; // fixed for MBBS
    }

    List<Course> coursesList = [];
    if (education.type == 'PG') {
      coursesList = pgCourses;
    } else if (education.type == 'SS') {
      coursesList = ssCourses;
    } else {
      return 0;
    }

    final course = coursesList.firstWhere(
      (c) => c.name == education.courseName,
      orElse: () => Course(name: '', duration: 0),
    );

    return course.duration;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context); // close drawer

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditForm(applicationId: 33),
                  ),
                );
              },
            ),

            // You can add more menu items here...
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Medical Professional Application Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return DegreesScreen();
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Details Section
              Container(
                key: _personalKey,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Personal Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (!_isEditing)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _toggleEditing('personal'),
                              tooltip: 'Edit Personal Details',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isEditing
                        ? _buildPersonalDetailsForm()
                        : _buildPersonalDetailsView(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Education Details Section
              _buildSectionHeader('Education Details', 'education'),
              _buildEducationDetailsSection(),

              const SizedBox(height: 24),

              // Fellowships Section
              _buildSectionHeader('Fellowships', 'fellowships'),
              _buildFellowshipsSection(),

              const SizedBox(height: 24),

              // Papers Section
              _buildSectionHeader('Papers', 'papers'),
              _buildPapersSection(),

              const SizedBox(height: 24),

              // Work Experience Section
              _buildSectionHeader('Work Experience', 'work'),
              _buildWorkExperienceSection(),

              const SizedBox(height: 24),

              // Medical Course Certificate Section
              _buildSectionHeader(
                'Currently Active Medical Councel Certificate',
                'certificate',
              ),
              if (_isEditing)
                _buildMedicalCertificateForm()
              else
                _buildMedicalCertificateView(),

              const SizedBox(height: 24),

              // Resume Upload Section
              _buildSectionHeader('Resume Upload', 'resume'),
              if (_isEditing)
                _buildResumeUploadSection()
              else if (_resumeFileName != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Resume: $_resumeFileName',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

              const SizedBox(height: 32),

              // Save / Edit Button
              Center(
                child: ElevatedButton(
                  onPressed:
                      _isEditing ? _saveForm : () => _toggleEditing('all'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Save Form' : 'Edit Form',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _toggleEditing(section),
              tooltip: 'Edit $title',
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsForm() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      // Column layout for mobile (fields stacked)
      return Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  text: 'Full Name',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 12, 12, 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            validator:
                (v) =>
                    (v == null || v.isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  text: 'Phone Number',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  children: [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),

            keyboardType: TextInputType.phone,
            validator:
                (v) =>
                    (v == null || v.isEmpty) ? 'Please enter your phone' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  text: 'Email Address',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  children: [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),

            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your email';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 3,
            validator:
                (v) =>
                    (v == null || v.isEmpty)
                        ? 'Please enter your address'
                        : null,
          ),
        ],
      );
    } else {
      // Existing row layout for web
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    label: RichText(
                      text: TextSpan(
                        text: 'Full Name',
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please enter your name'
                              : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please enter your phone'
                              : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please enter your email';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 3,
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please enter your address'
                              : null,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildPersonalDetailsView() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', _nameController.text),
            _buildInfoRow('Phone', _phoneController.text),
            _buildInfoRow('Email', _emailController.text),
            _buildInfoRow('Address', _addressController.text),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? 'Not provided' : value)),
        ],
      ),
    );
  }

  Widget _buildEducationDetailsSection() {
    return Container(
      key: _educationKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1️⃣ MBBS (always shown)
          _buildEducationDetailItem(educationDetails[0]),

          const SizedBox(height: 24),

          // 2️⃣ Have you done PG?
          Text('Have you done PG?'),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Yes'),
                  value: true,
                  groupValue: _hasPG,
                  onChanged: (v) => setState(() => _hasPG = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('No'),
                  value: false,
                  groupValue: _hasPG,
                  onChanged:
                      (value) => setState(() {
                        _hasPG = value!;
                        if (!value) pgDetails.clear();
                      }),
                ),
              ),
            ],
          ),
          if (_hasPG) ...[
            const SizedBox(height: 16),
            // show existing PG entries
            ...pgDetails.map((edu) => _buildEducationDetailItem(edu)),
            // Add More PG
            if (_isEditing)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add More PG'),
                onPressed: () {
                  setState(() {
                    pgDetails.add(EducationDetail(type: 'PG'));
                  });
                },
              ),
          ],

          const SizedBox(height: 24),

          // 3️⃣ Have you done SS?
          Text('Have you done SS?'),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Yes'),
                  value: true,
                  groupValue: _hasSS,
                  onChanged: (v) => setState(() => _hasSS = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('No'),
                  value: false,
                  groupValue: _hasSS,
                  onChanged:
                      (v) => setState(() {
                        _hasSS = v!;
                        if (!v) ssDetails.clear();
                      }),
                ),
              ),
            ],
          ),
          if (_hasSS) ...[
            const SizedBox(height: 16),
            // show existing SS entries
            ...ssDetails.map((edu) => _buildEducationDetailItem(edu)),
            // Add More SS
            if (_isEditing)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add More SS'),
                onPressed: () {
                  setState(() {
                    ssDetails.add(EducationDetail(type: 'SS'));
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEducationDetailItem(EducationDetail education) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              education.type,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              if (education.type != 'MBBS') ...[
                GestureDetector(
                  onTap: () async {
                    final courses =
                        education.type == 'PG' ? pgCourses : ssCourses;
                    if (courses.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Courses not loaded yet')),
                      );
                      return;
                    }
                    final selected = await _showSearchableCourseDialog(
                      courses,
                      education.courseName,
                    );
                    if (selected != null) {
                      setState(() {
                        education.courseName = selected;
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Course Name',
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      controller: TextEditingController(
                        text: education.courseName,
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Please select a course'
                                  : null,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                initialValue: education.collegeName,
                decoration: const InputDecoration(labelText: 'College Name'),
                onChanged: (value) => education.collegeName = value,
                validator:
                    (value) =>
                        (value == null || value.isEmpty)
                            ? 'Please enter college name'
                            : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: education.fromDateController,
                      decoration: const InputDecoration(labelText: 'From Date'),
                      readOnly: true,
                      onTap: () => _pickDate(education.fromDateController),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Please select from date'
                                  : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: education.toDateController,
                      decoration: const InputDecoration(labelText: 'To Date'),
                      readOnly: true,
                      onTap: () => _pickDate(education.toDateController),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select to date';
                        }
                        final fromDateText =
                            education.fromDateController.text.trim();
                        final toDateText =
                            education.toDateController.text.trim();
                        if (fromDateText.isEmpty)
                          return 'Select from date first';

                        try {
                          final fromDate = DateFormat(
                            'dd/MM/yyyy',
                          ).parseStrict(fromDateText);
                          final toDate = DateFormat(
                            'dd/MM/yyyy',
                          ).parseStrict(toDateText);

                          if (toDate.isBefore(fromDate)) {
                            return 'To Date cannot be before From Date';
                          }

                          final durationInYears =
                              toDate.difference(fromDate).inDays / 365.25;

                          if (education.type == 'MBBS' &&
                              durationInYears < 5.5) {
                            return 'Time period should be at least 5.5 years';
                          }

                          final requiredDuration = getSelectedCourseDuration(
                            education,
                          );
                          if (requiredDuration > 0 &&
                              durationInYears < requiredDuration) {
                            return 'Time period should be at least $requiredDuration years';
                          }
                        } catch (e) {
                          print('Date parsing error in validator: $e');
                          print(
                            'fromDateText="$fromDateText", toDateText="$value"',
                          );
                          return 'Invalid date format';
                        }

                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildInfoRow('Course', education.courseName),
              _buildInfoRow('College', education.collegeName),
              _buildInfoRow(
                'Period',
                '${education.fromDateController.text} to ${education.toDateController.text}',
              ),
            ],
            if (_isEditing && education.type != 'MBBS')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      if (education.type == 'PG') {
                        pgDetails.remove(education);
                      } else if (education.type == 'SS') {
                        ssDetails.remove(education);
                      }
                    });
                  },
                  child: const Text('Remove'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _getCourseDropdownItems(String type) {
    List<Course> coursesList;
    switch (type) {
      case 'MBBS':
        // For MBBS you still have hardcoded strings, so map them into Course objects on the fly:
        coursesList = [
          Course(name: 'MBBS', duration: 5),
          Course(name: 'BDS', duration: 5),
          Course(name: 'BAMS', duration: 5),
          Course(name: 'BHMS', duration: 5),
          Course(name: 'BUMS', duration: 5),
        ];
        break;
      case 'PG':
        coursesList = pgCourses;
        break;
      case 'SS':
        coursesList = ssCourses;
        break;
      default:
        coursesList = [
          Course(name: 'Certificate Course', duration: 1),
          Course(name: 'Diploma', duration: 1),
          Course(name: 'Other', duration: 1),
        ];
    }
    return coursesList
        .map(
          (course) => DropdownMenuItem<String>(
            value: course.name,
            child: Text(course.name),
          ),
        )
        .toList();
  }

  Widget _buildFellowshipsSection() {
    return Container(
      key: _fellowshipKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Have you done Fellowships?'),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Yes'),
                  value: true,
                  groupValue: _hasFellowships,
                  onChanged: (v) => setState(() => _hasFellowships = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('No'),
                  value: false,
                  groupValue: _hasFellowships,
                  onChanged: (v) {
                    setState(() {
                      _hasFellowships = v!;
                      if (!v) fellowships.clear();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_hasFellowships) ...[
            ...fellowships.asMap().entries.map(
              (e) => _buildFellowshipItem(e.value, e.key),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Fellowship'),
                onPressed: () {
                  setState(() {
                    fellowships.add(Fellowship());
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFellowshipItem(Fellowship fellowship, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fellowship ${index + 1}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              TextFormField(
                initialValue: fellowship.courseName,
                decoration: const InputDecoration(labelText: 'Course Name'),
                onChanged: (v) => fellowship.courseName = v,
              ),
              SizedBox(height: 10),
              TextFormField(
                initialValue: fellowship.collegeName,
                decoration: const InputDecoration(labelText: 'College Name'),
                onChanged: (v) => fellowship.collegeName = v,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: fellowship.fromDateController,
                      decoration: const InputDecoration(labelText: 'From Date'),
                      readOnly: true,
                      onTap: () => _pickDate(fellowship.fromDateController),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: fellowship.toDateController,
                      decoration: const InputDecoration(labelText: 'To Date'),
                      readOnly: true,
                      onTap: () => _pickDate(fellowship.toDateController),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildInfoRow('Course', fellowship.courseName),
              _buildInfoRow('College', fellowship.collegeName),
              _buildInfoRow(
                'Period',
                '${fellowship.fromDateController.text} to ${fellowship.toDateController.text}',
              ),
            ],
            if (_isEditing)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      fellowships.removeAt(index);
                    });
                  },
                  child: const Text('Remove'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersSection() {
    return Container(
      key: _papersKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Have you published Papers?'),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Yes'),
                  value: true,
                  groupValue: _hasPapers,
                  onChanged: (v) => setState(() => _hasPapers = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('No'),
                  value: false,
                  groupValue: _hasPapers,
                  onChanged: (v) {
                    setState(() {
                      _hasPapers = v!;
                      if (!v) papers.clear();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_hasPapers) ...[
            ...papers.asMap().entries.map(
              (e) => _buildPaperItem(e.value, e.key),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Paper'),
                onPressed: () {
                  setState(() {
                    papers.add(Paper());
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaperItem(Paper paper, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paper ${index + 1}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              TextFormField(
                initialValue: paper.name,
                decoration: const InputDecoration(labelText: 'Paper Name'),
                onChanged: (v) => paper.name = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: paper.description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onChanged: (v) => paper.description = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: paper.submittedDateController,
                decoration: const InputDecoration(labelText: 'Submitted On'),
                readOnly: true,
                onTap: () => _pickDate(paper.submittedDateController),
              ),
            ] else ...[
              _buildInfoRow('Name', paper.name),
              _buildInfoRow('Description', paper.description),
              _buildInfoRow('Submitted On', paper.submittedDateController.text),
            ],
            if (_isEditing)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      papers.removeAt(index);
                    });
                  },
                  child: const Text('Remove'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkExperienceSection() {
    return Container(
      key: _workKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Do you have Work Experience?'),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Yes'),
                  value: true,
                  groupValue: _hasWorkExperience,
                  onChanged: (v) => setState(() => _hasWorkExperience = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('No'),
                  value: false,
                  groupValue: _hasWorkExperience,
                  onChanged: (v) {
                    setState(() {
                      _hasWorkExperience = v!;
                      if (!v) workExperiences.clear();
                    });
                  },
                ),
              ),
            ],
          ),
          if (_hasWorkExperience) ...[
            ...workExperiences.asMap().entries.map(
              (e) => _buildWorkExperienceItem(e.value, e.key),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Work Experience'),
                onPressed: () {
                  setState(() {
                    workExperiences.add(WorkExperience());
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkExperienceItem(WorkExperience exp, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Experience ${index + 1}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              TextFormField(
                initialValue: exp.role,
                decoration: const InputDecoration(labelText: 'Role'),
                onChanged: (v) => exp.role = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: exp.name,
                decoration: const InputDecoration(labelText: 'Hospital Name'),
                onChanged: (v) => exp.name = v,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: exp.fromDateController,
                      decoration: const InputDecoration(labelText: 'From Date'),
                      readOnly: true,
                      onTap: () => _pickDate(exp.fromDateController),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: exp.toDateController,
                      decoration: const InputDecoration(labelText: 'To Date'),
                      readOnly: true,
                      onTap: () => _pickDate(exp.toDateController),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: exp.place,
                decoration: const InputDecoration(labelText: 'Place'),
                onChanged: (v) => exp.place = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: exp.description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onChanged: (v) => exp.description = v,
              ),
            ] else ...[
              _buildInfoRow('Role', exp.role),
              _buildInfoRow(
                'Period',
                '${exp.fromDateController.text} to ${exp.toDateController.text}',
              ),
              _buildInfoRow('Place', exp.place),
              _buildInfoRow('Description', exp.description),
            ],
            if (_isEditing)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      workExperiences.removeAt(index);
                    });
                  },
                  child: const Text('Remove'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalCertificateForm() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Column(
        children: [
          TextFormField(
            controller: _counselNameController,
            decoration: const InputDecoration(labelText: 'Counsel Name'),
            validator:
                (v) =>
                    (v == null || v.isEmpty)
                        ? 'Please enter counsel name'
                        : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _courseNameController,
            decoration: const InputDecoration(labelText: 'Course Name'),
            validator:
                (v) =>
                    (v == null || v.isEmpty)
                        ? 'Please enter course name'
                        : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _validityFromController,
                  decoration: const InputDecoration(labelText: 'Validity From'),
                  readOnly: true,
                  onTap: () => _pickDate(_validityFromController),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please select from date'
                              : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _validityToController,
                  decoration: const InputDecoration(labelText: 'Validity To'),
                  readOnly: true,
                  onTap: () => _pickDate(_validityToController),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please select to date'
                              : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registrationNumberController,
            decoration: const InputDecoration(
              labelText: 'Medical Course Registration Number',
            ),
            validator:
                (v) =>
                    (v == null || v.isEmpty)
                        ? 'Please enter registration number'
                        : null,
          ),
        ],
      );
    } else {
      // existing web layout (two fields side by side)
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _counselNameController,
                  decoration: const InputDecoration(labelText: 'Counsel Name'),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please enter counsel name'
                              : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _courseNameController,
                  decoration: const InputDecoration(labelText: 'Course Name'),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please enter course name'
                              : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _validityFromController,
                  decoration: const InputDecoration(labelText: 'Validity From'),
                  readOnly: true,
                  onTap: () => _pickDate(_validityFromController),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please select from date'
                              : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _validityToController,
                  decoration: const InputDecoration(labelText: 'Validity To'),
                  readOnly: true,
                  onTap: () => _pickDate(_validityToController),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Please select to date'
                              : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _registrationNumberController,
            decoration: const InputDecoration(
              labelText: 'Medical Course Registration Number',
            ),
            validator:
                (v) =>
                    (v == null || v.isEmpty)
                        ? 'Please enter registration number'
                        : null,
          ),
        ],
      );
    }
  }

  Widget _buildMedicalCertificateView() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          key: _certificateKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Counsel Name', _counselNameController.text),
              _buildInfoRow('Course Name', _courseNameController.text),
              _buildInfoRow(
                'Validity',
                '${_validityFromController.text} to ${_validityToController.text}',
              ),
              _buildInfoRow(
                'Registration Number',
                _registrationNumberController.text,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeUploadSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              const Icon(Icons.upload_file, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                _resumeFileName ?? 'No file selected',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickResume,
                child: const Text('Select Resume'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Supported formats: PDF, DOC, DOCX',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

String convertDateToBackendFormat(String dateStr) {
  try {
    final date = DateFormat('dd/MM/yyyy').parse(dateStr);
    return DateFormat('yyyy-MM-dd').format(date);
  } catch (e) {
    return dateStr; // fallback if parsing fails
  }
}

// Models
class EducationDetail {
  String type;
  String courseName = '';
  String collegeName = '';
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  String location = '';

  EducationDetail({required this.type});

  Map<String, dynamic> toJson() => {
    'type': type,
    'courseName': courseName,
    'collegeName': collegeName,
    'fromDate': convertDateToBackendFormat(fromDateController.text),
    'toDate': convertDateToBackendFormat(toDateController.text),
  };
}

class Fellowship {
  String courseName = '';
  String collegeName = '';
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'collegeName': collegeName,
    'fromDate': convertDateToBackendFormat(fromDateController.text),
    'toDate': convertDateToBackendFormat(toDateController.text),
  };
}

class Paper {
  String name = '';
  String description = '';
  final TextEditingController submittedDateController = TextEditingController();
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'submittedOn': convertDateToBackendFormat(submittedDateController.text),
  };
}

class WorkExperience {
  String role = '';
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  String place = '';
  String description = '';
  String name = '';

  Map<String, dynamic> toJson() => {
    'role': role,
    'name': name,
    'from': convertDateToBackendFormat(fromDateController.text),
    'to': convertDateToBackendFormat(toDateController.text),
    'place': place,
    'description': description,
  };
}

class Course {
  final String name;
  final double duration; // in years

  Course({required this.name, required this.duration});
}
