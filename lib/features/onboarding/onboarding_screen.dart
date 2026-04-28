import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/goal_pace_slider.dart';
import '../dashboard/dashboard_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Step 1 - Basics
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = 'male';

  // Step 2 - Goal
  final _goalWeightController = TextEditingController();
  String _goalPace = 'moderate';

  // Step 3 - Activity
  String _activityLevel = 'moderate';

  // Step 4 - Diet & Use
  String _dietType = 'nonveg';
  String _appUse = 'both';

  // Step 5 - Mantra
  final _mantraController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalWeightController.dispose();
    _mantraController.dispose();
    super.dispose();
  }

  double get _weight => double.tryParse(_weightController.text) ?? 0;
  double get _height => double.tryParse(_heightController.text) ?? 0;
  double get _bmi => (_height > 0) ? _weight / ((_height / 100) * (_height / 100)) : 0;

  String get _bmiCategory {
    if (_bmi <= 0) return '';
    if (_bmi < 18.5) return 'Underweight';
    if (_bmi < 25.0) return 'Normal';
    if (_bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color get _bmiColor {
    if (_bmi <= 0) return Colors.transparent;
    if (_bmi < 18.5) return Colors.blueAccent;
    if (_bmi < 25.0) return AppTheme.accent;
    if (_bmi < 30.0) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            (_ageController.text.isNotEmpty && int.tryParse(_ageController.text) != null) &&
            _weight > 0 &&
            _height > 0;
      case 1:
        return _goalWeightController.text.isNotEmpty &&
            double.tryParse(_goalWeightController.text) != null;
      case 2:
        return true;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _next() {
    if (!_canProceed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_currentPage < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _currentPage++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _currentPage--);
    }
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final profile = UserProfile.fromOnboarding(
        uid: uid,
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        weight: _weight,
        height: _height,
        gender: _gender,
        goalWeight: double.parse(_goalWeightController.text),
        activityLevel: _activityLevel,
        dietType: _dietType,
        appUse: _appUse,
        mantra: _mantraController.text.trim(),
        goalPace: _goalPace,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(profile.toMap());

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(5, (i) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentPage ? AppTheme.accent : AppTheme.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 8),

            // Back button
            Align(
              alignment: Alignment.centerLeft,
              child: _currentPage > 0
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _back,
                    )
                  : const SizedBox(height: 48),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step1Basics(
                    nameController: _nameController,
                    ageController: _ageController,
                    heightController: _heightController,
                    weightController: _weightController,
                    gender: _gender,
                    bmi: _bmi,
                    bmiCategory: _bmiCategory,
                    bmiColor: _bmiColor,
                    onGenderChanged: (v) => setState(() => _gender = v),
                    onFieldChanged: () => setState(() {}),
                  ),
                  _Step2Goal(
                    currentWeight: _weight,
                    goalWeightController: _goalWeightController,
                    height: _height,
                    age: int.tryParse(_ageController.text) ?? 25,
                    gender: _gender,
                    goalPace: _goalPace,
                    onPaceChanged: (p) => setState(() => _goalPace = p),
                    onFieldChanged: () => setState(() {}),
                  ),
                  _Step3Activity(
                    selected: _activityLevel,
                    onChanged: (v) => setState(() => _activityLevel = v),
                  ),
                  _Step4DietUse(
                    dietType: _dietType,
                    appUse: _appUse,
                    onDietChanged: (v) => setState(() => _dietType = v),
                    onUseChanged: (v) => setState(() => _appUse = v),
                  ),
                  _Step5Mantra(
                    mantraController: _mantraController,
                  ),
                ],
              ),
            ),

            // Next / Finish button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: AppTheme.background, strokeWidth: 2)
                      : Text(
                          _currentPage == 4 ? "Let's Go" : 'Continue',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 1: Basics
// ─────────────────────────────────────────────
class _Step1Basics extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final String gender;
  final double bmi;
  final String bmiCategory;
  final Color bmiColor;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onFieldChanged;

  const _Step1Basics({
    required this.nameController,
    required this.ageController,
    required this.heightController,
    required this.weightController,
    required this.gender,
    required this.bmi,
    required this.bmiCategory,
    required this.bmiColor,
    required this.onGenderChanged,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The Basics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text("Let's start with who you are.", style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),

          _OField(label: 'Your name', controller: nameController, onChanged: (_) => onFieldChanged()),
          const SizedBox(height: 16),
          _OField(label: 'Age', controller: ageController, keyboardType: TextInputType.number, onChanged: (_) => onFieldChanged()),
          const SizedBox(height: 16),

          // Gender toggle
          const Text('Gender', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _GenderChip(label: 'Male', value: 'male', selected: gender, onTap: onGenderChanged),
              const SizedBox(width: 12),
              _GenderChip(label: 'Female', value: 'female', selected: gender, onTap: onGenderChanged),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _OField(label: 'Height (cm)', controller: heightController, keyboardType: TextInputType.number, onChanged: (_) => onFieldChanged())),
              const SizedBox(width: 12),
              Expanded(child: _OField(label: 'Weight (kg)', controller: weightController, keyboardType: TextInputType.number, onChanged: (_) => onFieldChanged())),
            ],
          ),

          // Live BMI
          if (bmi > 0) ...[
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bmiColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bmiColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your BMI', style: TextStyle(color: Colors.white)),
                  Text(
                    '${bmi.toStringAsFixed(1)}  •  $bmiCategory',
                    style: TextStyle(color: bmiColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 2: Goal Weight
// ─────────────────────────────────────────────
class _Step2Goal extends StatefulWidget {
  final double currentWeight;
  final TextEditingController goalWeightController;
  final double height;
  final int age;
  final String gender;
  final String goalPace;
  final ValueChanged<String> onPaceChanged;
  final VoidCallback onFieldChanged;

  const _Step2Goal({
    required this.currentWeight,
    required this.goalWeightController,
    required this.height,
    required this.age,
    required this.gender,
    required this.goalPace,
    required this.onPaceChanged,
    required this.onFieldChanged,
  });

  @override
  State<_Step2Goal> createState() => _Step2GoalState();
}

class _Step2GoalState extends State<_Step2Goal> {
  double get _goalWeight =>
      double.tryParse(widget.goalWeightController.text) ?? 0;

  String get _goalLabel {
    final goal = _goalWeight;
    if (goal <= 0 || widget.currentWeight <= 0) return '';
    final diff = (goal - widget.currentWeight).abs();
    if (goal < widget.currentWeight) return 'Lose ${diff.toStringAsFixed(1)} kg';
    if (goal > widget.currentWeight) return 'Gain ${diff.toStringAsFixed(1)} kg';
    return 'Maintain weight';
  }

  double get _tdeeEstimate {
    if (widget.height <= 0 || widget.currentWeight <= 0) return 2000;
    double bmr = widget.gender == 'male'
        ? 10 * widget.currentWeight + 6.25 * widget.height - 5 * widget.age + 5
        : 10 * widget.currentWeight + 6.25 * widget.height - 5 * widget.age - 161;
    return bmr * 1.55; // moderate activity default
  }

  @override
  Widget build(BuildContext context) {
    final showPace = _goalWeight > 0 && widget.currentWeight > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Goal',
              style: TextStyle(fontSize: 28,
                  fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text('Where do you want to be?',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),

          if (widget.currentWeight > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                const Text('Current weight: ',
                    style: TextStyle(color: AppTheme.textSecondary)),
                Text('${widget.currentWeight.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ),

          _OField(
            label: 'Goal weight (kg)',
            controller: widget.goalWeightController,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              widget.onFieldChanged();
              setState(() {});
            },
          ),

          if (_goalLabel.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Text(_goalLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ],

          if (showPace) ...[
            const SizedBox(height: 24),
            const Text('Choose your pace',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('How fast do you want to reach your goal?',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            GoalPaceSlider(
              weight:            widget.currentWeight,
              goalWeight:        _goalWeight,
              tdee:              _tdeeEstimate,
              initialPace:       widget.goalPace,
              onPaceChanged:     widget.onPaceChanged,
              onCaloriesChanged: (_) {}, // calories computed server-side in fromOnboarding
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────
// STEP 3: Activity Level
// ─────────────────────────────────────────────
class _Step3Activity extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _Step3Activity({required this.selected, required this.onChanged});

  static const _options = [
    ('sedentary', 'Sedentary', 'Desk job, little to no exercise'),
    ('light', 'Lightly Active', 'Exercise 1–3 days/week'),
    ('moderate', 'Moderate', 'Exercise 3–5 days/week'),
    ('active', 'Very Active', 'Hard exercise 6–7 days/week'),
    ('athlete', 'Athlete', 'Twice a day or physical job'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity Level', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text('How active are you on a typical week?', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          ..._options.map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SelectionTile(
              title: o.$2,
              subtitle: o.$3,
              isSelected: selected == o.$1,
              onTap: () => onChanged(o.$1),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 4: Diet & App Use
// ─────────────────────────────────────────────
class _Step4DietUse extends StatelessWidget {
  final String dietType;
  final String appUse;
  final ValueChanged<String> onDietChanged;
  final ValueChanged<String> onUseChanged;

  const _Step4DietUse({
    required this.dietType,
    required this.appUse,
    required this.onDietChanged,
    required this.onUseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Diet & Goals', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text('Help us tailor your macros.', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),

          const Text('Diet type', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          ...([
            ('nonveg', 'Non-Vegetarian', 'Includes meat, fish, eggs'),
            ('veg', 'Vegetarian', 'No meat or fish'),
            ('vegan', 'Vegan', 'No animal products'),
          ]).map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectionTile(
              title: o.$2,
              subtitle: o.$3,
              isSelected: dietType == o.$1,
              onTap: () => onDietChanged(o.$1),
            ),
          )),

          const SizedBox(height: 24),
          const Text("What's the app for?", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          ...([
            ('both', 'Macros + Gym', 'Track food and workouts'),
            ('macros', 'Macros Only', 'Just track nutrition'),
            ('gym', 'Gym Only', 'Just track workouts'),
          ]).map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectionTile(
              title: o.$2,
              subtitle: o.$3,
              isSelected: appUse == o.$1,
              onTap: () => onUseChanged(o.$1),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STEP 5: Mantra
// ─────────────────────────────────────────────
class _Step5Mantra extends StatelessWidget {
  final TextEditingController mantraController;

  const _Step5Mantra({required this.mantraController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('One Last Thing', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          const Text("What do you want to hear when you're struggling?", style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),

          TextField(
            controller: mantraController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: '"Every rep counts." / "You showed up." / "Keep going."',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            "This will show up as a notification on tough days. You can skip this if you want.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
class _OField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _OField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _GenderChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.accent : Colors.transparent, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: isSelected ? AppTheme.accent : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionTile({required this.title, required this.subtitle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppTheme.accent : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? AppTheme.accent : Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
