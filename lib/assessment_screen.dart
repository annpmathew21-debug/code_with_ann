import 'package:flutter/material.dart';
import 'home_screen.dart';

class AssessmentScreen extends StatefulWidget {
  final String registeredName;
  final String chosenAvatar;
  final String registeredEmail;

  const AssessmentScreen({
    super.key,
    required this.registeredName,
    required this.chosenAvatar,
    required this.registeredEmail,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- 🌟 UPGRADED: Expanded Ranges & Professional Options ---
  // (Total Max Score remains exactly 120)
  final List<Map<String, dynamic>> assessmentQuestions = [
    {
      "question": "What is your Age range? 🎂",
      "options": [
        {"text": "Under 18", "score": 0},
        {"text": "18 - 25", "score": 0},
        {"text": "26 - 35", "score": 0},
        {"text": "36 - 45", "score": 0},
        {"text": "46 - 60", "score": 0},
        {"text": "Above 60", "score": 0},
      ]
    },
    {
      "question": "Select Height range 📏",
      "options": [
        {"text": "Below 150 cm", "score": 0},
        {"text": "150 - 160 cm", "score": 0},
        {"text": "161 - 170 cm", "score": 0},
        {"text": "171 - 180 cm", "score": 0},
        {"text": "Above 180 cm", "score": 0},
      ]
    },
    {
      "question": "Daily Water intake level? 💧",
      "options": [
        {"text": "Less than 3 Cups", "score": 0},
        {"text": "3 - 5 Cups", "score": 20},
        {"text": "6 - 8 Cups (Optimal) 🎉", "score": 40},
      ]
    },
    {
      "question": "Sleep status duration? 😴",
      "options": [
        {"text": "Less than 4 Hours (Poor)", "score": 0},
        {"text": "4 - 6 Hours", "score": 15},
        {"text": "7 - 8 Hours (Optimal) ✨", "score": 30},
        {"text": "More than 8 Hours", "score": 20},
      ]
    },
    {
      "question": "Exercise frequency metric? 🏋️",
      "options": [
        {"text": "Rarely", "score": 0},
        {"text": "1 - 2 times/week", "score": 10},
        {"text": "3 - 4 times/week", "score": 20},
        {"text": "Active Daily 🏃", "score": 30},
      ]
    },
    {
      "question": "Rate your Stress level? 🧠",
      "options": [
        {"text": "High Stress", "score": 0},
        {"text": "Moderate Stress", "score": 10},
        {"text": "Low / Calm Mind 🍏", "score": 20},
      ]
    },
  ];

  late List<int?> _selectedOptionIndexes;

  @override
  void initState() {
    super.initState();
    _selectedOptionIndexes = List.filled(assessmentQuestions.length, null);

    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _currentCalculatedScore {
    int total = 0;
    for (int i = 0; i < assessmentQuestions.length; i++) {
      if (_selectedOptionIndexes[i] != null) {
        total += assessmentQuestions[i]["options"][_selectedOptionIndexes[i]!]["score"] as int;
      }
    }
    return total;
  }

  int get _maxTotalScore {
    int maxScore = 0;
    for (var q in assessmentQuestions) {
      int highestOptionScore = 0;
      for (var opt in q["options"]) {
        if (opt["score"] > highestOptionScore) {
          highestOptionScore = opt["score"];
        }
      }
      maxScore += highestOptionScore;
    }
    return maxScore;
  }

  // 👈 🌟 FIXED LAG: ആനിമേഷൻ ഡിലേ വെറും 150ms ആക്കി കുറച്ചു!
  void _handleOptionSelect(int questionIndex, int optionIndex) {
    setState(() {
      _selectedOptionIndexes[questionIndex] = optionIndex;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_pageController.hasClients && _currentPage < assessmentQuestions.length) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic, // 👈 സ്മൂത്ത് ആനിമേഷൻ കർവ്
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double progress = (_currentPage) / assessmentQuestions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A3038)),
          onPressed: () {
            if (_currentPage > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text("Health Audit", style: TextStyle(color: Color(0xFF1A3038), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.teal.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              minHeight: 4,
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assessmentQuestions.length + 1,
                itemBuilder: (context, index) {
                  if (index == assessmentQuestions.length) {
                    return _buildResultPage();
                  }
                  return _buildQuestionPage(index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage(int qIndex) {
    final q = assessmentQuestions[qIndex];
    final options = q["options"] as List<Map<String, dynamic>>;

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q["question"],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A3038), height: 1.4, letterSpacing: -0.3),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, optIndex) {
                    Map<String, dynamic> opt = options[optIndex];
                    bool isSelected = _selectedOptionIndexes[qIndex] == optIndex;

                    return GestureDetector(
                        onTap: () => _handleOptionSelect(qIndex, optIndex),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.teal.withOpacity(0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isSelected ? Colors.teal : Colors.grey.shade200,
                                  width: isSelected ? 2.0 : 1.5
                              ),
                              boxShadow: isSelected
                                  ? []
                                  : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                        opt["text"],
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? Colors.teal : const Color(0xFF212529)
                                        )
                                    ),
                                  ),
                                  Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      size: 22,
                                      color: isSelected ? Colors.teal : Colors.grey.shade300
                                  ),
                                ]
                            )
                        )
                    );
                  },
                ),
              ),
            ]
        )
    );
  }

  Widget _buildResultPage() {
    bool isUserHealthy = _currentCalculatedScore >= (_maxTotalScore / 2);
    bool hasAnsweredAny = _selectedOptionIndexes.any((element) => element != null);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Audit Complete, ${widget.registeredName}! 🎉",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A3038), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            "Based on your responses, here is your personalized wellness index and action plan.",
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 32),

          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: !hasAnsweredAny
                      ? [const Color(0xFF78909C), const Color(0xFF455A64)]
                      : (isUserHealthy
                      ? [const Color(0xFF42E695), const Color(0xFF3BB2B8)]
                      : [const Color(0xFFFF758C), const Color(0xFFFF7EB3)]),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: (hasAnsweredAny && isUserHealthy ? const Color(0xFF3BB2B8) : const Color(0xFFFF758C)).withOpacity(0.3),
                      blurRadius: 16, offset: const Offset(0, 8)
                  )
                ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "WELLNESS SCORE",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    Text(
                      "$_currentCalculatedScore / $_maxTotalScore",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Text(
                  !hasAnsweredAny
                      ? "Please select your options to generate your customized wellness plan index tracker."
                      : (isUserHealthy
                      ? "Condition: HEALTHY 🟢\n\nPlan: Excellent balance! Keep up with your active metrics, regular workouts, and a balanced diet map on your main dashboard."
                      : "Condition: NEEDS CARE 🔴\n\nPlan: Focus on stress recovery. Increase your daily water intake to 8 cups, prioritize 8 hours of sleep, and log regular intervals."),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    chosenCourse: "General Wellness",
                    passedName: widget.registeredName,
                    passedAvatar: widget.chosenAvatar,
                    passedEmail: widget.registeredEmail,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF149A88),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              "Submit & Enter Dashboard",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}