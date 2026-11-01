import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'main.dart';
import 'database_helper.dart';

class HomeScreen extends StatefulWidget {
  final String chosenCourse;
  final String passedName;
  final String passedAvatar;
  final String passedEmail;

  const HomeScreen({
    super.key,
    this.chosenCourse = "General Wellness",
    this.passedName = "User",
    this.passedAvatar = "",
    this.passedEmail = ""
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int currentTabIndex = 0;
  String selectedMood = "Happy";
  Color currentMoodColor = Colors.teal;
  String moodMessage = "Take it easy. Proper rest ensures you bounce back stronger. 😇";

  // --- CORE TRACKING VARIABLES ---
  int waterCups = 0;
  int stepsCount = 0;
  double sleepHours = 0.0;
  int caloriesBurned = 0;
  List<bool> stretchChecks = [false, false, false];

  // BMI Tracking Variables
  double? userHeight;
  double? userWeight;
  double? userBmi;
  String userBmiStatus = "";

  // Medication Tracking Variables
  List<Map<String, dynamic>> customMedications = [];
  Timer? _medicationTimer;

  late String userName;
  late String selectedAvatar;
  late String userEmail;
  Uint8List? localWebBytes;
  String userStatus = "Stay Healthy!";

  bool isDarkMode = false;
  Color currentBgColor = const Color(0xFFEAF4F4);

  bool isWaterReminderEnabled = true;
  Timer? _hydrationTimer;
  int _alertRotationIndex = 0;

  Timer? _clockTimer;
  String _liveTimeStr = "";

  bool _syncCloud = true;

  late ConfettiController _confettiController;

  final TextEditingController _journalController = TextEditingController();
  List<String> _journalEntries = [];
  bool isPedometerEnabled = false;
  bool isSleepSoundsEnabled = false;

  final List<String> wellnessQuotes = [
    "A healthy outside starts from the inside. 🌱",
    "Small steps every day lead to big results. 🏃‍♂️",
    "Your health is an investment, not an expense. 💡",
    "Fall in love with taking care of yourself. ❤️",
    "Drink water, sleep well, and conquer the day! 💧"
  ];

  @override
  void initState() {
    super.initState();
    userName = widget.passedName;
    selectedAvatar = widget.passedAvatar;
    userEmail = widget.passedEmail.isNotEmpty ? widget.passedEmail : identityControllerTextValueDummyMappingFix();

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    if (isWaterReminderEnabled) {
      _startHydrationReminder();
    }

    _loadUserSavedData();
    _loadJournalEntries();
    _startLiveClock();
    _loadUserMetrics();
    _loadMedications();
    _startMedicationTimer();
  }

  @override
  void dispose() {
    _hydrationTimer?.cancel();
    _clockTimer?.cancel();
    _medicationTimer?.cancel();
    _confettiController.dispose();
    _journalController.dispose();
    super.dispose();
  }

  Future<void> _loadUserMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      waterCups = prefs.getInt('${userEmail}_waterCups') ?? 0;
      stepsCount = prefs.getInt('${userEmail}_stepsCount') ?? 0;
      sleepHours = prefs.getDouble('${userEmail}_sleepHours') ?? 0.0;
      caloriesBurned = prefs.getInt('${userEmail}_caloriesBurned') ?? 0;

      stretchChecks[0] = prefs.getBool('${userEmail}_stretch0') ?? false;
      stretchChecks[1] = prefs.getBool('${userEmail}_stretch1') ?? false;
      stretchChecks[2] = prefs.getBool('${userEmail}_stretch2') ?? false;
    });
  }

  Future<void> _loadJournalEntries() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _journalEntries = prefs.getStringList('journal_$userEmail') ?? [];
    });
  }

  Future<void> _saveJournalEntry() async {
    if (_journalController.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _journalEntries.insert(0, "${DateTime.now().toString().split(' ')[0]} : ${_journalController.text.trim()}");
      _journalController.clear();
    });
    await prefs.setStringList('journal_$userEmail', _journalEntries);
    FocusScope.of(context).unfocus();
  }

  Future<void> _loadMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedMeds = prefs.getString('${userEmail}_medications');

    if (savedMeds != null) {
      setState(() {
        List<dynamic> decoded = jsonDecode(savedMeds);
        customMedications = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      });
    } else {
      // Default initial medications with null times so users can set them
      setState(() {
        customMedications = [
          {"title": "Iron Supplement", "desc": "Take with food.", "time": null, "isChecked": false},
          {"title": "Vitamin C", "desc": "Boosts immune system.", "time": null, "isChecked": false},
          {"title": "Vitamin D3", "desc": "Essential for bone health.", "time": null, "isChecked": false},
          {"title": "Omega-3 Fish Oil", "desc": "Supports heart health.", "time": null, "isChecked": false},
        ];
      });
    }
  }

  Future<void> _saveMedications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${userEmail}_medications', jsonEncode(customMedications));
  }

  void _startMedicationTimer() {
    _medicationTimer?.cancel();
    _medicationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = TimeOfDay.now();
      for (var med in customMedications) {
        if (med['time'] != null && med['isChecked'] == false) {
          List<String> timeParts = med['time'].split(':');
          int medHour = int.parse(timeParts[0]);
          int medMinute = int.parse(timeParts[1]);

          if (now.hour == medHour && now.minute == medMinute) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⏰ Reminder: It's time to take your ${med['title']}! 💊", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 6),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: "Dismiss",
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
        }
      }
    });
  }

  String get _dailyQuote => wellnessQuotes[DateTime.now().day % wellnessQuotes.length];

  void _startLiveClock() {
    _updateClockString();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateClockString();
      }
    });
  }

  void _updateClockString() {
    final now = DateTime.now();
    int hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    hour = hour == 0 ? 12 : hour;
    final hourStr = hour.toString().padLeft(2, '0');

    setState(() {
      _liveTimeStr = "$hourStr:$minute:$second $ampm";
    });
  }

  Future<void> _loadUserSavedData() async {
    try {
      final savedUsers = await DatabaseHelper.findUser(userEmail);
      if (savedUsers != null && savedUsers['avatar'] != null) {
        String dbPath = savedUsers['avatar']!;
        if (dbPath.isNotEmpty) {
          setState(() {
            selectedAvatar = dbPath;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading image from DB: $e");
    }
  }

  Future<void> _downloadPDFReport() async {
    final pdf = pw.Document();

    double stepsRatio = (stepsCount / 10000).clamp(0.0, 1.0);
    double waterRatio = (waterCups / 8).clamp(0.0, 1.0);
    double sleepRatio = (sleepHours / 12).clamp(0.0, 1.0);
    double calRatio = (caloriesBurned / 4000).clamp(0.0, 1.0);

    int stepsPercentage = (stepsRatio * 100).toInt();
    int waterPercentage = (waterRatio * 100).toInt();
    int sleepPercentage = (sleepRatio * 100).toInt();
    int calPercentage = (calRatio * 100).toInt();

    int overallScore = (((stepsRatio + waterRatio + sleepRatio + calRatio) / 4) * 100).toInt();

    final PdfColor tealColor = PdfColor.fromHex('#149A88');
    final PdfColor blueColor = PdfColor.fromHex('#42A5F5');
    final PdfColor purpleColor = PdfColor.fromHex('#AB47BC');
    final PdfColor orangeColor = PdfColor.fromHex('#FF7043');
    final PdfColor lightTeal = PdfColor.fromHex('#E0F2F1');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("WELLNESS COMPANION", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: tealColor, letterSpacing: 1.2)),
                          pw.Text("Personal Health Report", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text("Live Healthy. Live Happy.", style: pw.TextStyle(fontSize: 10, color: tealColor, fontWeight: pw.FontWeight.bold)),
                        ]
                    ),
                  ]
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey300, thickness: 1.5),
              pw.SizedBox(height: 10),

              pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text("Report Date\n${DateTime.now().toString().split(' ')[0]}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
                    pw.Container(width: 1, height: 20, color: PdfColors.grey300),
                    pw.SizedBox(width: 16),
                    pw.Expanded(child: pw.Text("Prepared For\n$userName", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
                  ]
              ),
              pw.SizedBox(height: 20),

              pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 6,
                        child: pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey300),
                                borderRadius: pw.BorderRadius.circular(12)
                            ),
                            child: pw.Row(
                                children: [
                                  pw.Container(
                                    width: 50, height: 50,
                                    decoration: pw.BoxDecoration(color: lightTeal, shape: pw.BoxShape.circle),
                                    child: pw.Center(child: pw.Text(userName[0].toUpperCase(), style: pw.TextStyle(fontSize: 24, color: tealColor, fontWeight: pw.FontWeight.bold))),
                                  ),
                                  pw.SizedBox(width: 16),
                                  pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text("USER PROFILE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: tealColor)),
                                        pw.SizedBox(height: 6),
                                        pw.Text("Name:            $userName", style: const pw.TextStyle(fontSize: 10)),
                                        pw.Text("Identifier:      $userEmail", style: const pw.TextStyle(fontSize: 10)),
                                        if (userBmi != null) ...[
                                          pw.Text("Height:          $userHeight cm", style: const pw.TextStyle(fontSize: 10)),
                                          pw.Text("Weight:         $userWeight kg", style: const pw.TextStyle(fontSize: 10)),
                                          pw.Text("BMI:              ${userBmi!.toStringAsFixed(1)} ($userBmiStatus)", style: const pw.TextStyle(fontSize: 10)),
                                        ],
                                        pw.SizedBox(height: 4),
                                        pw.Container(
                                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: pw.BoxDecoration(color: lightTeal, borderRadius: pw.BorderRadius.circular(4)),
                                            child: pw.Text(userStatus, style: pw.TextStyle(fontSize: 9, color: tealColor, fontWeight: pw.FontWeight.bold))
                                        )
                                      ]
                                  )
                                ]
                            )
                        )
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(12)),
                            child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text("\"", style: pw.TextStyle(fontSize: 30, color: tealColor, fontWeight: pw.FontWeight.bold)),
                                  pw.Text("Small steps every day lead to big changes.", style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800)),
                                ]
                            )
                        )
                    )
                  ]
              ),
              pw.SizedBox(height: 24),

              pw.Text("METRICS SUMMARY", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: tealColor)),
              pw.SizedBox(height: 12),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPdfMetricCard("STEPS TAKEN", "$stepsCount", "/ 10,000 steps", stepsPercentage, tealColor),
                    pw.SizedBox(width: 10),
                    _buildPdfMetricCard("WATER INTAKE", "$waterCups / 8", "Cups", waterPercentage, blueColor),
                    pw.SizedBox(width: 10),
                    _buildPdfMetricCard("SLEEP DURATION", "$sleepHours / 12", "Hours", sleepPercentage, purpleColor),
                    pw.SizedBox(width: 10),
                    _buildPdfMetricCard("CALORIES BURNED", "$caloriesBurned", "/ 4,000 kcal", calPercentage, orangeColor),
                  ]
              ),
              pw.SizedBox(height: 24),

              pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(color: lightTeal, borderRadius: pw.BorderRadius.circular(16)),
                  child: pw.Row(
                      children: [
                        pw.Container(
                            width: 100, height: 100,
                            decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: tealColor, width: 8)),
                            child: pw.Center(
                                child: pw.Column(
                                    mainAxisAlignment: pw.MainAxisAlignment.center,
                                    children: [
                                      pw.Text("$overallScore%", style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: tealColor)),
                                      pw.Text("WELLNESS", style: const pw.TextStyle(fontSize: 7)),
                                    ]
                                )
                            )
                        ),
                        pw.SizedBox(width: 30),
                        pw.Expanded(
                            child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text("OVERALL WEEKLY SCORE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: tealColor)),
                                  pw.SizedBox(height: 8),
                                  pw.Text(
                                      overallScore >= 70
                                          ? "Great job! You are maintaining a healthy balance.\nKeep focusing on your metrics."
                                          : "Needs improvement. Try to hit your daily water and sleep goals for a better index.",
                                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5)
                                  )
                                ]
                            )
                        )
                      ]
                  )
              ),
              pw.SizedBox(height: 24),

              pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("HEALTH INSIGHTS", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: tealColor)),
                              pw.SizedBox(height: 10),
                              _buildInsightRow(waterRatio >= 0.75, "Excellent hydration level", "Increase water intake"),
                              _buildInsightRow(sleepRatio >= 0.58, "Consistent sleep schedule", "Needs more restful sleep"),
                              _buildInsightRow(stepsRatio >= 0.5, "Daily activity goal achieved", "Increase daily steps"),
                              _buildInsightRow(calRatio >= 0.5, "Calorie target maintained", "Focus on active calorie burn"),
                            ]
                        )
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("RECOMMENDATIONS", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: tealColor)),
                              pw.SizedBox(height: 10),
                              pw.Bullet(text: "Continue your current healthy routine", style: const pw.TextStyle(fontSize: 10)),
                              pw.Bullet(text: "Stay hydrated throughout the day", style: const pw.TextStyle(fontSize: 10)),
                              pw.Bullet(text: "Take regular stretch breaks", style: const pw.TextStyle(fontSize: 10)),
                              pw.Bullet(text: "Maintain your sleep cycle", style: const pw.TextStyle(fontSize: 10)),
                            ]
                        )
                    )
                  ]
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Confidential Health Report\nThis report is intended for personal use only.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                    pw.Text("Generated by\nWELLNESS COMPANION", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: tealColor)),
                  ]
              )
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Health_Report_${userName.replaceAll(" ", "_")}.pdf',
    );
  }

  pw.Widget _buildPdfMetricCard(String title, String mainVal, String subVal, int percentage, PdfColor color) {
    return pw.Expanded(
        child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 30, height: 30, decoration: pw.BoxDecoration(color: PdfColor(color.red, color.green, color.blue, 0.2), shape: pw.BoxShape.circle)),
                  pw.SizedBox(height: 10),
                  pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text(mainVal, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                  pw.Text(subVal, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  pw.SizedBox(height: 8),
                  pw.Container(height: 4, width: double.infinity, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2))),
                  pw.SizedBox(height: 4),
                  pw.Text("$percentage%", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
                ]
            )
        )
    );
  }

  pw.Widget _buildInsightRow(bool isGood, String goodText, String badText) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
            children: [
              pw.Container(width: 12, height: 12, decoration: pw.BoxDecoration(color: isGood ? PdfColors.green : PdfColors.orange, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 8),
              pw.Text(isGood ? goodText : badText, style: const pw.TextStyle(fontSize: 10)),
            ]
        )
    );
  }

  void _openBMICalculator() {
    TextEditingController heightCtrl = TextEditingController(text: userHeight != null ? userHeight.toString() : "");
    TextEditingController weightCtrl = TextEditingController(text: userWeight != null ? userWeight.toString() : "");
    double? bmiResult = userBmi;
    String bmiStatus = userBmiStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: const Text("BMI Calculator ⚖️", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Weight (kg)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                if (bmiResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Text("Your BMI: ${bmiResult!.toStringAsFixed(1)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                        Text("Status: $bmiStatus", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
              ElevatedButton(
                onPressed: () {
                  double? h = double.tryParse(heightCtrl.text);
                  double? w = double.tryParse(weightCtrl.text);
                  if (h != null && w != null && h > 0) {
                    double hm = h / 100;
                    double bmi = w / (hm * hm);
                    String status = "Normal";
                    if (bmi < 18.5) status = "Underweight";
                    else if (bmi >= 25) status = "Overweight";

                    this.setState(() {
                      userHeight = h;
                      userWeight = w;
                      userBmi = bmi;
                      userBmiStatus = status;
                    });

                    setDialogState(() {
                      bmiResult = bmi;
                      bmiStatus = status;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: const Text("Calculate"),
              )
            ],
          );
        },
      ),
    );
  }

  void _openFocusTimer() {
    int totalSeconds = 25 * 60;
    Timer? focusTimer;
    bool isRunning = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {

            void startTimer() {
              if (isRunning) return;
              setDialogState(() => isRunning = true);
              focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (!mounted) { timer.cancel(); return; }
                setDialogState(() {
                  if (totalSeconds > 0) {
                    totalSeconds--;
                  } else {
                    timer.cancel();
                    isRunning = false;
                    ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Focus Session Complete! 🍅🎉"), backgroundColor: Colors.teal));
                  }
                });
              });
            }

            void pauseTimer() {
              focusTimer?.cancel();
              setDialogState(() => isRunning = false);
            }

            int m = totalSeconds ~/ 60;
            int s = totalSeconds % 60;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              title: const Center(child: Text("Focus Timer 🍅", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Stay focused. Block distractions.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  Text("${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.deepOrange)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: isRunning ? pauseTimer : startTimer,
                        style: ElevatedButton.styleFrom(backgroundColor: isRunning ? Colors.orange : Colors.teal, foregroundColor: Colors.white),
                        child: Text(isRunning ? "Pause" : "Start Focus"),
                      ),
                      IconButton(
                        onPressed: () {
                          focusTimer?.cancel();
                          setDialogState(() { totalSeconds = 25 * 60; isRunning = false; });
                        },
                        icon: const Icon(Icons.refresh, color: Colors.grey),
                      )
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () { focusTimer?.cancel(); Navigator.pop(context); },
                  child: const Text("Close", style: TextStyle(color: Colors.redAccent)),
                )
              ],
            );
          }
      ),
    ).then((_) => focusTimer?.cancel());
  }

  void _openStretchRoutines() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("5-Min Stretch 🧘‍♀️", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                      Icon(Icons.self_improvement, color: Colors.teal, size: 28),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildStretchItem(
                      "1. Neck Rolls",
                      "Gently roll your neck in circles to release tension. (60 Secs)",
                      stretchChecks[0],
                          () async {
                        setSheetState(() => stretchChecks[0] = !stretchChecks[0]);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('${userEmail}_stretch0', stretchChecks[0]);
                      }
                  ),
                  _buildStretchItem(
                      "2. Shoulder Shrugs",
                      "Lift your shoulders to your ears, hold, and release. (60 Secs)",
                      stretchChecks[1],
                          () async {
                        setSheetState(() => stretchChecks[1] = !stretchChecks[1]);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('${userEmail}_stretch1', stretchChecks[1]);
                      }
                  ),
                  _buildStretchItem(
                      "3. Torso Twist",
                      "Sit straight and twist your upper body to each side. (60 Secs)",
                      stretchChecks[2],
                          () async {
                        setSheetState(() => stretchChecks[2] = !stretchChecks[2]);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('${userEmail}_stretch2', stretchChecks[2]);
                      }
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      int completedCount = stretchChecks.where((c) => c).length;
                      if(completedCount > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stretching routine completed! Great job. 💪"), backgroundColor: Colors.teal));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You didn't complete any stretches today! Try tomorrow. 🌱")));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                    child: const Text("Mark as Completed"),
                  )
                ],
              ),
            );
          }
      ),
    );
  }

  void _openAddMedicationDialog(StateSetter setSheetState) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController descCtrl = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text("Add Custom Medication 💊", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: "Medicine Name", prefixIcon: Icon(Icons.medication_liquid)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: "Description / Dosage", prefixIcon: Icon(Icons.description)),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(selectedTime == null ? "Select Reminder Time" : "Time: ${selectedTime!.format(context)}"),
                      leading: const Icon(Icons.access_time, color: Colors.teal),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setDialogState(() => selectedTime = pickedTime);
                        }
                      },
                    )
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.isNotEmpty) {
                        setState(() {
                          customMedications.add({
                            "title": titleCtrl.text.trim(),
                            "desc": descCtrl.text.trim(),
                            "time": selectedTime != null ? "${selectedTime!.hour}:${selectedTime!.minute}" : null,
                            "isChecked": false
                          });
                        });
                        _saveMedications();
                        setSheetState(() {});
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    child: const Text("Add"),
                  )
                ],
              );
            }
        )
    );
  }

  void _openMedicationAlert() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                  left: 24.0, right: 24.0, top: 24.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.medication, color: Colors.redAccent, size: 28),
                          SizedBox(width: 8),
                          Text("Daily Medication 💊", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.redAccent, size: 30),
                        onPressed: () => _openAddMedicationDialog(setSheetState),
                        tooltip: "Add Custom Medicine",
                      )
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  if (customMedications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text("No medications added yet.\nPress + to add.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...customMedications.asMap().entries.map((entry) {
                      int index = entry.key;
                      var med = entry.value;

                      String timeText = "Set Time";
                      if (med['time'] != null) {
                        List<String> timeParts = med['time'].split(':');
                        TimeOfDay tod = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
                        timeText = tod.format(context);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () {
                                setSheetState(() {
                                  customMedications[index]['isChecked'] = !customMedications[index]['isChecked'];
                                });
                                setState(() {});
                                _saveMedications();
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Icon(med['isChecked'] ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.teal, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      med['title'],
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: med['isChecked'] ? TextDecoration.lineThrough : null, color: med['isChecked'] ? Colors.grey : (isDarkMode ? Colors.white : Colors.black87))
                                  ),
                                  Text(med['desc'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    TimeOfDay? initialTime = TimeOfDay.now();
                                    if (med['time'] != null) {
                                      List<String> parts = med['time'].split(':');
                                      initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                                    }

                                    TimeOfDay? pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: initialTime,
                                    );

                                    if (pickedTime != null) {
                                      setSheetState(() {
                                        customMedications[index]['time'] = "${pickedTime.hour}:${pickedTime.minute}";
                                      });
                                      setState(() {});
                                      _saveMedications();
                                    }
                                  },
                                  icon: const Icon(Icons.access_time, size: 16, color: Colors.redAccent),
                                  label: Text(timeText, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setSheetState(() {
                                      customMedications.removeAt(index);
                                    });
                                    setState(() {});
                                    _saveMedications();
                                  },
                                )
                              ],
                            )
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      int completedCount = customMedications.where((c) => c['isChecked'] == true).length;
                      if(completedCount > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medication logged! Stay healthy. 💊"), backgroundColor: Colors.teal));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No medication logged today.")));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                    child: const Text("Log Completed Medication"),
                  )
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildStretchItem(String title, String desc, bool isChecked, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isChecked ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.teal, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.grey : (isDarkMode ? Colors.white : Colors.black87)
                      )
                  ),
                  Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _openBreathingExercise() {
    bool hasStarted = false;
    bool isTimerStarted = false;
    bool isInhaling = true;
    int phaseSecondsLeft = 4;
    int totalSecondsLeft = 60;
    Timer? breathTimer;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {

                void startBreathing() {
                  if (!mounted) return;
                  setDialogState(() {
                    hasStarted = true;
                    isTimerStarted = true;
                  });

                  breathTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                    if (!mounted) {
                      timer.cancel();
                      return;
                    }
                    setDialogState(() {
                      totalSecondsLeft--;
                      phaseSecondsLeft--;

                      if (totalSecondsLeft <= 0) {
                        timer.cancel();
                        if (Navigator.canPop(context)) Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text("Great job! You completed 1 minute of mindfulness. 🌟", style: TextStyle(fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.teal,
                          ),
                        );
                        return;
                      }

                      if (phaseSecondsLeft <= 0) {
                        isInhaling = !isInhaling;
                        phaseSecondsLeft = 4;
                      }
                    });
                  });
                }

                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Breathing Exercise 🧘‍♂️", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 8),
                        Text(
                            hasStarted ? "Total time left: 0:${totalSecondsLeft.toString().padLeft(2, '0')}" : "Get ready to relax",
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 40),

                        AnimatedContainer(
                          duration: Duration(seconds: hasStarted ? 4 : 1),
                          curve: Curves.easeInOut,
                          width: !hasStarted ? 150 : (isInhaling ? 200 : 120),
                          height: !hasStarted ? 150 : (isInhaling ? 200 : 120),
                          decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(!hasStarted ? 0.8 : (isInhaling ? 0.3 : 0.8)),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.teal.withOpacity(0.4),
                                    blurRadius: !hasStarted ? 10 : (isInhaling ? 40 : 10),
                                    spreadRadius: !hasStarted ? 0 : (isInhaling ? 20 : 0)
                                )
                              ]
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  !hasStarted ? "Ready?" : (isInhaling ? "Breathe In" : "Breathe Out"),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: (!hasStarted || !isInhaling) ? Colors.white : Colors.teal[800], fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  !hasStarted ? "Go" : "$phaseSecondsLeft",
                                  style: TextStyle(fontWeight: FontWeight.w900, color: (!hasStarted || !isInhaling) ? Colors.white : Colors.teal[800], fontSize: 32),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (!hasStarted)
                              ElevatedButton(
                                onPressed: startBreathing,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                child: const Text("Start", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            TextButton(
                              onPressed: () {
                                breathTimer?.cancel();
                                Navigator.pop(context);
                              },
                              child: Text(hasStarted ? "Finish Early" : "Close", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }
          );
        }
    ).then((_) {
      breathTimer?.cancel();
    });
  }

  void _startHydrationReminder() {
    _hydrationTimer?.cancel();
    _hydrationTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        String alertText = "Hydration Reminder! Time to take a sip of water. 💧";
        Color alertBg = Colors.blueAccent;

        setState(() {
          _alertRotationIndex = (_alertRotationIndex + 1) % 4;
        });

        final currentHour = DateTime.now().hour;

        if (_alertRotationIndex == 1) {
          alertText = "Walk Alert: Keep moving to reach your daily 10,000 steps goal! 🚶";
          alertBg = Colors.teal;
        } else if (_alertRotationIndex == 2) {
          if (currentHour >= 21 || currentHour < 6) {
            alertText = "Sleep Alert: Sound sleep balances your wellness index! Get enough rest tonight. 😴";
            alertBg = Colors.green;
          } else {
            alertText = "Hydration Check! Keep drinking water throughout the day. 💧";
            alertBg = Colors.blueAccent;
          }
        } else if (_alertRotationIndex == 3) {
          alertText = "Calorie Burn Alert: Keep active to burn those extra calories effectively! 🔥";
          alertBg = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alertText, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: alertBg,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _stopHydrationReminder() {
    _hydrationTimer?.cancel();
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning ☀️";
    if (hour < 17) return "Good Afternoon 🌤️";
    return "Good Evening 🌙";
  }

  void _updateMoodSelection(String emoji, String label) {
    setState(() {
      selectedMood = label;
      if (label == "Happy") {
        currentMoodColor = Colors.teal;
        currentBgColor = const Color(0xFFEAF4F4);
        moodMessage = "Fantastic energy! Let's hit those goals today. 😊";
      } else if (label == "Calm") {
        currentMoodColor = Colors.green;
        currentBgColor = const Color(0xFFE8F5E9);
        moodMessage = "A peaceful mind is a powerful mind. Stay balanced. 😇";
      } else if (label == "Tired") {
        currentMoodColor = Colors.orangeAccent;
        currentBgColor = const Color(0xFFFFF3E0);
        moodMessage = "Take it easy. Proper rest ensures you bounce back stronger. 😴";
      } else if (label == "Sad") {
        currentMoodColor = Colors.redAccent;
        currentBgColor = const Color(0xFFFFEBEE);
        moodMessage = "It's okay not to feel okay. Focus on gentle wellness today. ❤️";
      }
    });
  }

  void _showUserProfileDialog(Color cardBg, Color mainTextColor, Color subTextColor) {
    final nameFieldController = TextEditingController(text: userName);
    final statusFieldController = TextEditingController(text: userStatus);

    String dialogImagePath = selectedAvatar;
    Uint8List? dialogWebBytes = localWebBytes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            bool isUserHealthy = waterCups >= 6 && stepsCount >= 5000 && sleepHours >= 7.0;

            Future<void> pickDialogImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

              if (pickedFile != null) {
                if (kIsWeb) {
                  final bytes = await pickedFile.readAsBytes();
                  setDialogState(() {
                    dialogWebBytes = bytes;
                    dialogImagePath = pickedFile.path;
                  });
                } else {
                  setDialogState(() {
                    dialogImagePath = File(pickedFile.path).absolute.path;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              content: SingleChildScrollView(
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: pickDialogImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.teal.withValues(alpha: 0.1),
                              backgroundImage: dialogImagePath.isNotEmpty && !kIsWeb && !dialogImagePath.startsWith('blob:')
                                  ? FileImage(File(dialogImagePath))
                                  : null,
                              child: dialogImagePath.isEmpty
                                  ? const Icon(Icons.person, size: 40, color: Colors.teal)
                                  : (kIsWeb || dialogImagePath.startsWith('blob:')
                                  ? (dialogWebBytes != null
                                  ? ClipOval(child: Image.memory(dialogWebBytes!, width: 80, height: 80, fit: BoxFit.cover))
                                  : ClipOval(child: Image.network(dialogImagePath, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.teal))))
                                  : null),
                            ),
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameFieldController,
                        autofillHints: const [AutofillHints.name],
                        keyboardType: TextInputType.name,
                        decoration: InputDecoration(labelText: "Edit Profile Name", labelStyle: TextStyle(color: subTextColor), border: const OutlineInputBorder()),
                        style: TextStyle(color: mainTextColor),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: statusFieldController,
                        decoration: InputDecoration(labelText: "Edit Custom Status", labelStyle: TextStyle(color: subTextColor), border: const OutlineInputBorder()),
                        style: TextStyle(color: mainTextColor),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: isUserHealthy ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: Text(isUserHealthy ? "Status: Healthy 🟢" : "Status: Not Healthy 🔴", style: TextStyle(fontWeight: FontWeight.bold, color: isUserHealthy ? Colors.green : Colors.red)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          final savedUsers = await DatabaseHelper.findUser(userEmail);
                          await DatabaseHelper.saveUserData(
                            nameFieldController.text.trim(),
                            userEmail,
                            savedUsers != null ? savedUsers['password']! : "123456",
                            dialogImagePath,
                          );

                          setState(() {
                            userName = nameFieldController.text.trim();
                            userStatus = statusFieldController.text.trim();
                            selectedAvatar = dialogImagePath;
                            localWebBytes = dialogWebBytes;
                          });

                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 44)
                        ),
                        child: const Text("Save & Apply Updates"),
                      )
                    ],
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                ),
              ),
            );
          }
      ),
    );
  }

  String identityControllerTextValueDummyMappingFix() {
    return userName == "User" ? "DefaultUserEmail" : userName.toLowerCase().replaceAll(' ', '') + "@gmail.com";
  }

  void _showColorPickerDialog() {
    final List<Color> customColors = [
      const Color(0xFFEAF4F4), Colors.white, const Color(0xFFE8F1F5),
      const Color(0xFFEDF2F4), const Color(0xFFF7F4F9), const Color(0xFFF0E6EF),
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pick Background Customization"),
        content: Wrap(
          spacing: 12, runSpacing: 12,
          children: customColors.map((color) => GestureDetector(
            onTap: () {
              setState(() => currentBgColor = color);
              Navigator.pop(context);
            },
            child: Container(width: 50, height: 50, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey))),
          )).toList(),
        ),
      ),
    );
  }

  void _handleLogOutAction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out Account?"),
        content: const Text("Are you sure you want to log out from Wellness Companion?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolboxCard(String title, String icon, VoidCallback onTap, Color cardBg, Color mainTextColor, Color targetBorderColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: targetBorderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: mainTextColor), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color appBg = isDarkMode ? const Color(0xFF121212) : currentBgColor;
    Color cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    Color mainTextColor = isDarkMode ? Colors.white : const Color(0xFF1A3038);
    Color subTextColor = isDarkMode ? Colors.white70 : const Color(0xFF5C7178);
    Color targetBorderColor = isDarkMode ? Colors.white10 : const Color(0xFFCCE3DE);

    final List<Widget> tabScreens = [
      _buildDashboardView(appBg, cardBg, mainTextColor, subTextColor, targetBorderColor),
      _buildAnalyticsView(cardBg, mainTextColor, subTextColor),
      _buildSettingsView(cardBg, mainTextColor, subTextColor),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (currentTabIndex > 0) {
          setState(() {
            currentTabIndex = 0;
          });
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: appBg,
        body: Stack(
          children: [
            SafeArea(child: tabScreens[currentTabIndex]),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                maxBlastForce: 10,
                minBlastForce: 4,
                emissionFrequency: 0.05,
                numberOfParticles: 40,
                gravity: 0.15,
                shouldLoop: false,
                colors: const [Colors.teal, Colors.blueAccent, Colors.orangeAccent, Colors.green],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: cardBg,
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          currentIndex: currentTabIndex,
          onTap: (index) => setState(() => currentTabIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.bubble_chart_rounded), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.tune_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView(Color appBg, Color cardBg, Color mainTextColor, Color subTextColor, Color targetBorderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Hello, $userName", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: mainTextColor, letterSpacing: -0.5)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Text("🔥 Day 1", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_getTimeBasedGreeting(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 4),
                    Text(_dailyQuote, style: TextStyle(fontSize: 13, color: subTextColor, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showUserProfileDialog(cardBg, mainTextColor, subTextColor),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.withValues(alpha: 0.08),
                  backgroundImage: selectedAvatar.isNotEmpty && !kIsWeb && !selectedAvatar.startsWith('blob:')
                      ? FileImage(File(selectedAvatar))
                      : null,
                  child: selectedAvatar.isEmpty
                      ? const Icon(Icons.person, size: 26, color: Colors.teal)
                      : (kIsWeb || selectedAvatar.startsWith('blob:')
                      ? (localWebBytes != null
                      ? ClipOval(child: Image.memory(localWebBytes!, width: 56, height: 56, fit: BoxFit.cover))
                      : ClipOval(child: Image.network(selectedAvatar, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.teal))))
                      : null),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          Text("Wellness Toolbox 🧰", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainTextColor)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildToolboxCard("BMI Calc", "⚖️", _openBMICalculator, cardBg, mainTextColor, targetBorderColor),
                const SizedBox(width: 12),
                _buildToolboxCard("Focus Time", "🍅", _openFocusTimer, cardBg, mainTextColor, targetBorderColor),
                const SizedBox(width: 12),
                _buildToolboxCard("Stretch", "🧘‍♀️", _openStretchRoutines, cardBg, mainTextColor, targetBorderColor),
                const SizedBox(width: 12),
                _buildToolboxCard("Medication", "💊", _openMedicationAlert, cardBg, mainTextColor, targetBorderColor),
              ],
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: _openBreathingExercise,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.teal.shade300, Colors.teal.shade700]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Start Breathing Exercise", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Take 1 minute to relax your mind 🧘", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: currentMoodColor.withOpacity(0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(color: currentMoodColor.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))
                ]
            ),
            child: Text(moodMessage, style: TextStyle(color: mainTextColor, fontSize: 15, fontWeight: FontWeight.w600, height: 1.5)),
          ),
          const SizedBox(height: 28),
          Text("How are you feeling today?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainTextColor)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPremiumMoodIcon("😊", "Happy", cardBg, subTextColor, targetBorderColor),
              _buildPremiumMoodIcon("😇", "Calm", cardBg, subTextColor, targetBorderColor),
              _buildPremiumMoodIcon("😴", "Tired", cardBg, subTextColor, targetBorderColor),
              _buildPremiumMoodIcon("😔", "Sad", cardBg, subTextColor, targetBorderColor),
            ],
          ),
          const SizedBox(height: 32),
          Text("Your Daily Metrics Panel", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainTextColor)),
          const SizedBox(height: 16),

          _buildPinterestListCard("Premium Steps Tracker", "$stepsCount / 10,000 steps", stepsCount / 10000, Icons.directions_walk, Colors.teal, cardBg, mainTextColor, subTextColor, targetBorderColor, type: "steps"),
          _buildPinterestListCard("Water Intake", "$waterCups / 8 Cups", waterCups / 8, Icons.local_drink, Colors.blueAccent, cardBg, mainTextColor, subTextColor, targetBorderColor, type: "water"),
          _buildPinterestListCard("Sleep Duration", "$sleepHours / 12 Hours", sleepHours / 12, Icons.bedtime, Colors.green, cardBg, mainTextColor, subTextColor, targetBorderColor, type: "sleep"),
          _buildPinterestListCard("Calories Burned", "$caloriesBurned / 4,000 kcal", caloriesBurned / 4000, Icons.local_fire_department, Colors.orange, cardBg, mainTextColor, subTextColor, targetBorderColor, type: "calories"),

          const SizedBox(height: 32),

          Text("Daily Wellness Journal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainTextColor)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: targetBorderColor)),
            child: Column(
              children: [
                TextField(
                  controller: _journalController,
                  maxLines: 2,
                  style: TextStyle(color: mainTextColor),
                  decoration: InputDecoration(
                      hintText: "How was your day? Write your thoughts here...",
                      hintStyle: TextStyle(color: subTextColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDarkMode ? Colors.black12 : Colors.grey.shade50
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _saveJournalEntry,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text("Save Note"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
                if (_journalEntries.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: min(3, _journalEntries.length),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.bookmark_border, size: 16, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_journalEntries[index], style: TextStyle(color: mainTextColor, fontSize: 13, fontStyle: FontStyle.italic))),
                          ],
                        ),
                      );
                    },
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalyticsView(Color cardBg, Color mainTextColor, Color subTextColor) {
    double stepsProgress = (stepsCount / 10000).clamp(0.0, 1.0);
    double waterProgress = (waterCups / 8).clamp(0.0, 1.0);

    int stepsPercentage = (stepsProgress * 100).toInt();
    int waterPercentage = (waterProgress * 100).toInt();
    int overallScore = ((stepsProgress + waterProgress) * 50).toInt();

    bool hasHydrationBadge = waterCups >= 8;
    bool hasStepBadge = stepsCount >= 10000;
    bool hasSleepBadge = sleepHours >= 8;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Weekly Analytics", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: mainTextColor)),
                  const SizedBox(height: 4),
                  Text("Activity split ratio for this week", style: TextStyle(color: subTextColor, fontSize: 13)),
                ],
              ),
              IconButton(
                onPressed: _showLeaderboardSheet,
                icon: const Icon(Icons.emoji_events_rounded, color: Colors.orangeAccent, size: 32),
                tooltip: "View Leaderboard",
              )
            ],
          ),
          const SizedBox(height: 36),

          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: stepsProgress,
                    strokeWidth: 22,
                    backgroundColor: Colors.teal.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: waterProgress,
                    strokeWidth: 18,
                    backgroundColor: Colors.green.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$overallScore%", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: mainTextColor)),
                    Text("Overall Score", style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 40),

          Text("Achievements & Badges 🏆", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mainTextColor)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBadgeIcon(Icons.water_drop, "Hydration King", hasHydrationBadge, Colors.blueAccent),
              _buildBadgeIcon(Icons.directions_walk, "Step Master", hasStepBadge, Colors.teal),
              _buildBadgeIcon(Icons.bedtime, "Sleep Guru", hasSleepBadge, Colors.deepPurpleAccent),
            ],
          ),

          const SizedBox(height: 30),
          Text("Weekly Metric Balance (Live Data)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: mainTextColor)),
          const SizedBox(height: 16),
          _buildChartLegendRow("Steps Distribution ($stepsPercentage%)", Colors.teal, mainTextColor),
          _buildChartLegendRow("Hydration Ratio ($waterPercentage%)", Colors.blueAccent, mainTextColor),
          _buildChartLegendRow("Sleep Consistency ($sleepHours Hours)", Colors.green, mainTextColor),
          _buildChartLegendRow("Calorie Burn Efficiency ($caloriesBurned kcal)", Colors.orange, mainTextColor),

          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _downloadPDFReport,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text("Download PDF Report"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, String label, bool isUnlocked, Color activeColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: isUnlocked ? activeColor.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: isUnlocked ? activeColor : Colors.grey, width: 2)
          ),
          child: Icon(isUnlocked ? icon : Icons.lock_outline, color: isUnlocked ? activeColor : Colors.grey, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUnlocked ? activeColor : Colors.grey)),
      ],
    );
  }

  Widget _buildChartLegendRow(String label, Color color, Color mainTextColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: mainTextColor)),
        ],
      ),
    );
  }

  void _showLeaderboardSheet() async {
    final prefs = await SharedPreferences.getInstance();
    String? existingUsersRaw = prefs.getString('all_registered_users');
    List<dynamic> allUsers = [];
    if (existingUsersRaw != null) allUsers = jsonDecode(existingUsersRaw);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Global Leaderboard 🏆", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const Text("Top Wellness Champions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),

              Expanded(
                child: allUsers.isEmpty
                    ? const Center(child: Text("No users to rank yet.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  itemCount: allUsers.length,
                  itemBuilder: (context, index) {
                    final user = allUsers[index];
                    final avatarPath = user['avatar'] ?? "";

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: index == 0 ? Colors.orange.withOpacity(0.1) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: index == 0 ? Colors.orange : Colors.grey.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.teal.withOpacity(0.1),
                          backgroundImage: avatarPath.isNotEmpty && !kIsWeb && !avatarPath.startsWith('blob:')
                              ? FileImage(File(avatarPath))
                              : null,
                          child: avatarPath.isEmpty
                              ? const Icon(Icons.person, color: Colors.teal)
                              : (kIsWeb || avatarPath.startsWith('blob:')
                              ? ClipOval(child: Image.network(avatarPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.teal)))
                              : null),
                        ),
                        title: Text(user['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("Level: Champion", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        trailing: index == 0
                            ? const Icon(Icons.military_tech_rounded, color: Colors.orange, size: 28)
                            : Text("#${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminUsersSheet() async {
    final prefs = await SharedPreferences.getInstance();
    String? existingUsersRaw = prefs.getString('all_registered_users');
    List<dynamic> allUsers = [];
    if (existingUsersRaw != null) allUsers = jsonDecode(existingUsersRaw);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Registered Users DB 🗄️", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A3038))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Text("Total Active Users: ${allUsers.length}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15)),
              const SizedBox(height: 16),

              Expanded(
                child: allUsers.isEmpty
                    ? const Center(child: Text("No users registered yet.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  itemCount: allUsers.length,
                  itemBuilder: (context, index) {
                    final user = allUsers[index];
                    final avatarPath = user['avatar'] ?? "";

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.teal.withOpacity(0.1),
                          backgroundImage: avatarPath.isNotEmpty && !kIsWeb && !avatarPath.startsWith('blob:')
                              ? FileImage(File(avatarPath))
                              : null,
                          child: avatarPath.isEmpty
                              ? const Icon(Icons.person, color: Colors.teal)
                              : (kIsWeb || avatarPath.startsWith('blob:')
                              ? ClipOval(child: Image.network(avatarPath, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.teal)))
                              : null),
                        ),
                        title: Text(user['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(user['email'] ?? "No Email", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        trailing: const Icon(Icons.verified_user, color: Colors.green, size: 20),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHelpCentreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Help Centre 📋", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A3038))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            _buildFAQItem("How do the active alerts work?", "When toggled on, the workspace pushes unique water, walk, sleep, and calorie burn coaching triggers every 60 seconds."),
            _buildFAQItem("Are my profile picture sync paths safe?", "Yes, all avatar image paths are completely isolated and mapped exclusively under your unique account identifier."),
            _buildFAQItem("Can I reset my metric tracking logs?", "Yes, you can safely wipe your daily logs clean back to 0 anytime from the Account & Settings panel."),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting with Wellness Support Desk... 📞")));
              },
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text("Contact Live Support Desk"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
          const SizedBox(height: 4),
          Text(answer, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3)),
        ],
      ),
    );
  }

  void _openAccountSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Account Parameters ⚙️", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.contact_mail_outlined, color: Colors.teal),
                title: const Text("Registered Identifier Account", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(userEmail, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Automated Local DB Backup", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text("Keeps data isolated safely inside device storage", style: TextStyle(fontSize: 12)),
                value: _syncCloud,
                activeColor: Colors.teal,
                onChanged: (val) => setSheetState(() => _syncCloud = val),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  setState(() {
                    waterCups = 0; stepsCount = 0; sleepHours = 0.0; caloriesBurned = 0;
                    stretchChecks = [false, false, false];
                  });

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('${userEmail}_waterCups', 0);
                  await prefs.setInt('${userEmail}_stepsCount', 0);
                  await prefs.setDouble('${userEmail}_sleepHours', 0.0);
                  await prefs.setInt('${userEmail}_caloriesBurned', 0);
                  await prefs.setBool('${userEmail}_stretch0', false);
                  await prefs.setBool('${userEmail}_stretch1', false);
                  await prefs.setBool('${userEmail}_stretch2', false);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All localized tracking records reset back to default! 🧹")));
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
                label: const Text("Reset Tracking Dashboard Progress Logs", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsView(Color cardBg, Color mainTextColor, Color subTextColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: cardBg,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.teal.withValues(alpha: 0.1),
                  backgroundImage: selectedAvatar.isNotEmpty && !kIsWeb && !selectedAvatar.startsWith('blob:')
                      ? FileImage(File(selectedAvatar))
                      : null,
                  child: selectedAvatar.isEmpty
                      ? const Icon(Icons.person, size: 36, color: Colors.teal)
                      : (kIsWeb || selectedAvatar.startsWith('blob:')
                      ? ClipOval(child: Image.network(selectedAvatar, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.teal)))
                      : null),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Hi, $userName!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: mainTextColor)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showUserProfileDialog(cardBg, mainTextColor, subTextColor),
                        child: const Row(
                          children: [
                            Text("Edit Profile", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(width: 4),
                            Icon(Icons.edit, size: 14, color: Colors.redAccent),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _liveTimeStr,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal, fontFamily: 'Courier'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _buildSettingsListGroup(cardBg, mainTextColor, subTextColor, [
            _buildSettingsItem(Icons.water_drop_outlined, "Active Wellness Alerts", "Reminds walk, sleep & water tracking every 1 min", subTextColor, mainTextColor,
                trailingWidget: Switch(
                  value: isWaterReminderEnabled,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() {
                      isWaterReminderEnabled = val;
                      if (val) _startHydrationReminder();
                      else _stopHydrationReminder();
                    });
                  },
                )
            ),
            _buildSettingsItem(Icons.directions_run_rounded, "Auto Pedometer Tracking", "Use device sensor to track steps", subTextColor, mainTextColor,
                trailingWidget: Switch(
                  value: isPedometerEnabled,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() => isPedometerEnabled = val);
                    if (val) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedometer activated successfully!")));
                    }
                  },
                )
            ),
            _buildSettingsItem(Icons.library_music_rounded, "Ambient Sleep Sounds", "Play relaxing forest rain sounds", subTextColor, mainTextColor,
                trailingWidget: Switch(
                  value: isSleepSoundsEnabled,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() => isSleepSoundsEnabled = val);
                    if (val) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playing Ambient Rain Sounds... 🌧️🎵"), backgroundColor: Colors.indigo));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Music Stopped.")));
                    }
                  },
                )
            ),
            _buildSettingsItem(Icons.color_lens_outlined, "Custom Theme Background", "Change workspace dashboard colors", subTextColor, mainTextColor, onTap: _showColorPickerDialog),
            _buildSettingsItem(Icons.dark_mode_outlined, "Dark Mode Theme", "Midnight mode customization", subTextColor, mainTextColor,
                trailingWidget: Switch(
                  value: isDarkMode,
                  activeColor: Colors.teal,
                  onChanged: (val) => setState(() => isDarkMode = val),
                )
            ),
          ]),

          const SizedBox(height: 12),

          _buildSettingsListGroup(cardBg, mainTextColor, subTextColor, [
            _buildSettingsItem(Icons.admin_panel_settings_rounded, "Admin: User Database", "View all registered users and data", subTextColor, mainTextColor, onTap: _showAdminUsersSheet),
          ]),

          const SizedBox(height: 12),

          _buildSettingsListGroup(cardBg, mainTextColor, subTextColor, [
            _buildSettingsItem(Icons.help_outline_rounded, "Help Centre", "FAQ, customer support and advice", subTextColor, mainTextColor, onTap: _openHelpCentreSheet),
            _buildSettingsItem(Icons.verified_user_outlined, "Account & Settings", "Privacy security parameters", subTextColor, mainTextColor, onTap: _openAccountSettingsSheet),
          ]),

          const SizedBox(height: 12),

          _buildSettingsListGroup(cardBg, mainTextColor, subTextColor, [
            _buildSettingsItem(Icons.logout_rounded, "Log Out Account", "Sign out securely from wellness companion", subTextColor, Colors.redAccent, onTap: _handleLogOutAction),
          ]),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsListGroup(Color cardBg, Color mainTextColor, Color subTextColor, List<Widget> items) {
    return Material(
      color: cardBg,
      child: Column(
        children: List.generate(items.length * 2 - 1, (index) {
          if (index.isOdd) return const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFEEEEEE));
          return items[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, Color subTextColor, Color titleColor, {Widget? trailingWidget, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: titleColor == Colors.redAccent ? Colors.redAccent : Colors.teal.withValues(alpha: 0.8), size: 24),
      title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12)),
      trailing: trailingWidget ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
    );
  }

  Widget _buildPremiumMoodIcon(String emoji, String label, Color cardBg, Color subTextColor, Color targetBorderColor) {
    bool isSelected = selectedMood == label;
    return GestureDetector(
      onTap: () => _updateMoodSelection(emoji, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
            color: isSelected ? currentMoodColor.withOpacity(0.12) : cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? currentMoodColor : targetBorderColor, width: 1.5),
            boxShadow: isSelected ? [BoxShadow(color: currentMoodColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : null
        ),
        child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 13, color: isSelected ? currentMoodColor : subTextColor, fontWeight: FontWeight.bold))
            ]
        ),
      ),
    );
  }

  Widget _buildPinterestListCard(String title, String value, double progressValue, IconData icon, Color color, Color cardBg, Color mainTextColor, Color subTextColor, Color targetBorderColor, {required String type}) {
    bool isMaxReached = progressValue >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: targetBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 12, offset: const Offset(0, 4))
          ]
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.08), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                        const SizedBox(height: 4),
                        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: mainTextColor))
                      ]
                  )
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                    icon: Icon(Icons.add_circle, color: isMaxReached ? Colors.grey[300] : Colors.teal, size: 28),
                    padding: EdgeInsets.zero,
                    onPressed: isMaxReached ? null : () async {

                      bool wereAllMaxed = (waterCups >= 8 && stepsCount >= 10000 && sleepHours >= 12.0 && caloriesBurned >= 4000);

                      setState(() {
                        if (type == "water" && waterCups < 8) waterCups++;
                        else if (type == "steps" && stepsCount < 10000) stepsCount += 500;
                        else if (type == "sleep" && sleepHours < 12.0) sleepHours += 0.5;
                        else if (type == "calories" && caloriesBurned < 4000) caloriesBurned += 100;
                      });

                      final prefs = await SharedPreferences.getInstance();
                      if (type == "water") await prefs.setInt('${userEmail}_waterCups', waterCups);
                      if (type == "steps") await prefs.setInt('${userEmail}_stepsCount', stepsCount);
                      if (type == "sleep") await prefs.setDouble('${userEmail}_sleepHours', sleepHours);
                      if (type == "calories") await prefs.setInt('${userEmail}_caloriesBurned', caloriesBurned);

                      bool areAllMaxed = (waterCups >= 8 && stepsCount >= 10000 && sleepHours >= 12.0 && caloriesBurned >= 4000);

                      if (!wereAllMaxed && areAllMaxed) {
                        _confettiController.play();
                      }
                    }
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressValue.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          )
        ],
      ),
    );
  }
}