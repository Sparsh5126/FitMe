import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/widgets/goal_pace_slider.dart';
import '../../dashboard/providers/user_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          error: (e, _) =>
              Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
          data: (profile) {
            if (profile == null) return const SizedBox();
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profile',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26)),
                    const SizedBox(height: 20),
                    _AccountCard(profile: profile),
                    const SizedBox(height: 20),
                    _StatsRow(profile: profile),
                    const SizedBox(height: 24),
                    const _SectionHeader('Personal Details'),
                    const SizedBox(height: 12),
                    _DetailTile(icon: Icons.cake_rounded, label: 'Age', value: '${profile.age} years'),
                    _DetailTile(icon: Icons.height_rounded, label: 'Height', value: '${profile.height.toStringAsFixed(0)} cm'),
                    _DetailTile(icon: Icons.monitor_weight_rounded, label: 'Current Weight', value: '${profile.weight} kg'),
                    _DetailTile(icon: Icons.flag_rounded, label: 'Goal Weight', value: '${profile.goalWeight} kg'),
                    _DetailTile(icon: Icons.directions_run_rounded, label: 'Activity Level', value: _activityLabel(profile.activityLevel)),
                    _DetailTile(icon: Icons.restaurant_rounded, label: 'Diet Type', value: _capitalize(profile.dietType)),
                    _DetailTile(icon: Icons.fitness_center_rounded, label: 'App Use', value: _appUseLabel(profile.appUse)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionHeader('Daily Macro Goals'),
                        TextButton.icon(
                          onPressed: () => _showEditGoals(context, profile, ref),
                          icon: const Icon(Icons.tune_rounded, size: 15, color: AppTheme.accent),
                          label: const Text('Edit Goals',
                              style: TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MacroGoalRow(profile: profile),
                    const SizedBox(height: 24),
                    if (profile.mantra.isNotEmpty) ...[
                      const _SectionHeader('Your Mantra'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                        ),
                        child: Text('"${profile.mantra}"',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontStyle: FontStyle.italic)),
                      ),
                      const SizedBox(height: 24),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _showEditSheet(context, profile, ref),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit Profile',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surface,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditGoals(BuildContext context, UserProfile profile, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGoalsSheet(profile: profile, ref: ref),
    );
  }

  void _showEditSheet(BuildContext context, UserProfile profile, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: profile, ref: ref),
    );
  }

  String _activityLabel(String level) {
    const map = {
      'sedentary': 'Sedentary',
      'light': 'Lightly Active',
      'moderate': 'Moderate',
      'active': 'Very Active',
      'athlete': 'Athlete',
    };
    return map[level] ?? level;
  }

  String _appUseLabel(String use) {
    const map = {'both': 'Macros + Gym', 'macros': 'Macros Only', 'gym': 'Gym Only'};
    return map[use] ?? use;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────
// ACCOUNT CARD
// ─────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final UserProfile profile;
  const _AccountCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 26,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    'BMI: ${profile.bmi.toStringAsFixed(1)} • ${profile.bmiCategory}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Anonymous Account',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final UserProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final toGo = (profile.goalWeight - profile.weight).abs();
    final isLosing = profile.goalWeight < profile.weight;

    return Row(
      children: [
        _StatTile(
            label: isLosing ? 'To Lose' : 'To Gain',
            value: '${toGo.toStringAsFixed(1)} kg',
            color: AppTheme.accent),
        const SizedBox(width: 12),
        _StatTile(
            label: 'Daily Calories',
            value: '${profile.dynamicCalories}',
            color: Colors.orangeAccent),
        const SizedBox(width: 12),
        _StatTile(
            label: 'Protein Goal',
            value: '${profile.dynamicProtein}g',
            color: Colors.blueAccent),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MACRO GOAL ROW
// ─────────────────────────────────────────────
class _MacroGoalRow extends StatelessWidget {
  final UserProfile profile;
  const _MacroGoalRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _MacroTile('Protein', '${profile.dynamicProtein}g', Colors.blueAccent),
      const SizedBox(width: 10),
      _MacroTile('Carbs', '${profile.dynamicCarbs}g', Colors.orangeAccent),
      const SizedBox(width: 10),
      _MacroTile('Fats', '${profile.dynamicFats}g', Colors.purpleAccent),
      const SizedBox(width: 10),
      _MacroTile('Calories', '${profile.dynamicCalories}', AppTheme.accent),
    ]);
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _MacroTile(this.label, this.value, this.color, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DETAIL TILE
// ─────────────────────────────────────────────
class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EDIT PROFILE SHEET
// ─────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final UserProfile profile;
  final WidgetRef ref;
  const _EditProfileSheet({required this.profile, required this.ref});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _goalWeightCtrl;
  late TextEditingController _mantraCtrl;
  late String _gender;
  late String _activityLevel;
  late String _dietType;
  late String _appUse;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _ageCtrl = TextEditingController(text: widget.profile.age.toString());
    _heightCtrl = TextEditingController(text: widget.profile.height.toString());
    _weightCtrl = TextEditingController(text: widget.profile.weight.toString());
    _goalWeightCtrl =
        TextEditingController(text: widget.profile.goalWeight.toString());
    _mantraCtrl = TextEditingController(text: widget.profile.mantra);
    _gender = widget.profile.gender;
    _activityLevel = widget.profile.activityLevel;
    _dietType = widget.profile.dietType;
    _appUse = widget.profile.appUse;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _goalWeightCtrl.dispose();
    _mantraCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = UserProfile.fromOnboarding(
      uid: widget.profile.uid,
      name: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text) ?? widget.profile.age,
      weight: double.tryParse(_weightCtrl.text) ?? widget.profile.weight,
      height: double.tryParse(_heightCtrl.text) ?? widget.profile.height,
      gender: _gender,
      goalWeight:
          double.tryParse(_goalWeightCtrl.text) ?? widget.profile.goalWeight,
      activityLevel: _activityLevel,
      dietType: _dietType,
      appUse: _appUse,
      mantra: _mantraCtrl.text.trim(),
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .update(updated.toMap());
    widget.ref.invalidate(userProfileProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Edit Profile',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 20),
            _EditField(label: 'Name', controller: _nameCtrl, numeric: false),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _EditField(label: 'Age', controller: _ageCtrl)),
              const SizedBox(width: 14),
              Expanded(
                  child: _EditField(
                      label: 'Height (cm)', controller: _heightCtrl)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _EditField(
                      label: 'Current Weight (kg)', controller: _weightCtrl)),
              const SizedBox(width: 14),
              Expanded(
                  child: _EditField(
                      label: 'Goal Weight (kg)', controller: _goalWeightCtrl)),
            ]),
            const SizedBox(height: 14),
            _EditField(
                label: 'Your Mantra', controller: _mantraCtrl, numeric: false),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Gender',
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _gender = v!),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Activity Level',
              value: _activityLevel,
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
                DropdownMenuItem(value: 'light', child: Text('Lightly Active')),
                DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                DropdownMenuItem(value: 'active', child: Text('Very Active')),
                DropdownMenuItem(value: 'athlete', child: Text('Athlete')),
              ],
              onChanged: (v) => setState(() => _activityLevel = v!),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Diet Type',
              value: _dietType,
              items: const [
                DropdownMenuItem(value: 'nonveg', child: Text('Non-Veg')),
                DropdownMenuItem(value: 'veg', child: Text('Vegetarian')),
                DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
              ],
              onChanged: (v) => setState(() => _dietType = v!),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'App Use',
              value: _appUse,
              items: const [
                DropdownMenuItem(value: 'both', child: Text('Macros + Gym')),
                DropdownMenuItem(value: 'macros', child: Text('Macros Only')),
                DropdownMenuItem(value: 'gym', child: Text('Gym Only')),
              ],
              onChanged: (v) => setState(() => _appUse = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const CircularProgressIndicator(
                        color: AppTheme.background, strokeWidth: 2)
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;
  const _EditField(
      {required this.label, required this.controller, this.numeric = true});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surface,
        // Issue 2: proper contentPadding so label + value don't overlap/clip
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16));
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// EDIT GOALS SHEET  — Issue 2: Target Cal field fixed
// ─────────────────────────────────────────────
class _EditGoalsSheet extends StatefulWidget {
  final UserProfile profile;
  final WidgetRef ref;
  const _EditGoalsSheet({required this.profile, required this.ref});

  @override
  State<_EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends State<_EditGoalsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _calsCtrl;
  late String _pace;
  int _manualCals = 0;
  int _paceCals = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _pace = widget.profile.goalPace;
    _manualCals = widget.profile.dynamicCalories;
    _paceCals = widget.profile.dynamicCalories;
    _calsCtrl =
        TextEditingController(text: widget.profile.dynamicCalories.toString());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _calsCtrl.dispose();
    super.dispose();
  }

  Map<String, int> _computeMacros(int targetCals) {
    final p = widget.profile;
    double proteinMult =
        (p.appUse == 'gym' || p.appUse == 'both') ? 2.0 : 1.6;
    if (p.dietType == 'nonveg') proteinMult += 0.1;
    final protein = (p.weight * proteinMult).round().clamp(100, 300);
    final fats = ((targetCals * 0.25) / 9).round();
    final carbs =
        ((targetCals - protein * 4 - fats * 9) / 4).round().clamp(50, 500);
    return {
      'calories': targetCals,
      'protein': protein,
      'carbs': carbs,
      'fats': fats
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final finalCals = _tabCtrl.index == 0 ? _manualCals : _paceCals;
    final m = _computeMacros(finalCals);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .update({
      'dynamicCalories': m['calories'],
      'dynamicProtein': m['protein'],
      'dynamicCarbs': m['carbs'],
      'dynamicFats': m['fats'],
      'goalPace': _pace,
    });
    widget.ref.invalidate(userProfileProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final p = widget.profile;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Edit Goals',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 4),
          Text(
              '${UserProfile.paceLabel(p.goalPace)} pace  •  ${p.dynamicCalories} kcal/day',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.accent,
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [Tab(text: 'Manual'), Tab(text: 'By Pace')],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 320,
            child: TabBarView(controller: _tabCtrl, children: [
              // ── Manual tab ────────────────────────────────────────
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),
                // Issue 2: Fixed Target Cal field — proper height & padding
                TextField(
                  controller: _calsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Target Calories',
                    suffixText: 'kcal/day',
                    suffixStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    labelStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surface,
                    // Key fix: explicit contentPadding keeps text vertically
                    // centered and prevents the label from being clipped
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(
                      () => _manualCals = int.tryParse(v) ?? _manualCals),
                ),
                const SizedBox(height: 16),
                if (_manualCals > 0) ...[
                  const Text('Auto macro split:',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  Builder(builder: (_) {
                    final m = _computeMacros(_manualCals);
                    return Row(children: [
                      _GoalChip('Protein', '${m['protein']}g', Colors.blueAccent),
                      const SizedBox(width: 8),
                      _GoalChip('Carbs', '${m['carbs']}g', Colors.orangeAccent),
                      const SizedBox(width: 8),
                      _GoalChip('Fats', '${m['fats']}g', Colors.purpleAccent),
                    ]);
                  }),
                ],
              ]),

              // ── Pace tab ──────────────────────────────────────────
              GoalPaceSlider(
                weight: p.weight,
                goalWeight: p.goalWeight,
                tdee: p.tdee,
                initialPace: _pace,
                onPaceChanged: (pace) => setState(() => _pace = pace),
                onCaloriesChanged: (cals) => setState(() => _paceCals = cals),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const CircularProgressIndicator(
                      color: AppTheme.background, strokeWidth: 2)
                  : const Text('Save Goals',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _GoalChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ]),
        ),
      );
}