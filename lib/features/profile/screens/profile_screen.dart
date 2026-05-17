import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/core/models/user_profile.dart';
import 'package:fitme/core/widgets/goal_pace_slider.dart';
import 'package:fitme/features/dashboard/providers/user_provider.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/nutrition/services/local_nutrition_service.dart';
import 'package:fitme/features/gamification/screens/wrapped_screen.dart';
import 'package:fitme/features/fitpoints/services/fitpoints_service.dart';
import 'package:fitme/features/fitpoints/models/fitpoints_models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: theme.colors.accent),
          ),
          error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.red)),
          ),
          data: (profile) {
            if (profile == null) return const SizedBox();
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        color: theme.colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AccountCard(profile: profile, theme: theme),
                    const SizedBox(height: 20),
                    _StatsRow(profile: profile, theme: theme),
                    const SizedBox(height: 24),
                    _SectionHeader('Personal Details', theme: theme),
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.cake_rounded,
                      label: 'Age',
                      value: '${profile.age} years',
                      theme: theme,
                    ),
                    _DetailTile(
                      icon: Icons.height_rounded,
                      label: 'Height',
                      value: '${profile.height.toStringAsFixed(0)} cm',
                      theme: theme,
                    ),
                    _DetailTile(
                      icon: Icons.monitor_weight_rounded,
                      label: 'Current Weight',
                      value: '${profile.weight} kg',
                      theme: theme,
                    ),
                    _DetailTile(
                      icon: Icons.flag_rounded,
                      label: 'Goal Weight',
                      value: '${profile.goalWeight} kg',
                      theme: theme,
                    ),
                    _DetailTile(
                      icon: Icons.directions_run_rounded,
                      label: 'Activity Level',
                      value: _activityLabel(profile.activityLevel),
                      theme: theme,
                    ),
                    _DetailTile(
                      icon: Icons.restaurant_rounded,
                      label: 'Diet Type',
                      value: _capitalize(profile.dietType),
                      theme: theme,
                    ),
                    _DetailTile(
                      icon: Icons.fitness_center_rounded,
                      label: 'App Use',
                      value: _appUseLabel(profile.appUse),
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionHeader('Daily Macro Goals', theme: theme),
                        TextButton.icon(
                          onPressed: () =>
                              _showEditGoals(context, profile, ref),
                          icon: Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: theme.colors.accent,
                          ),
                          label: Text(
                            'Edit Goals',
                            style: TextStyle(
                              color: theme.colors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MacroGoalRow(profile: profile, theme: theme),
                    const SizedBox(height: 24),
                    if (profile.mantra.isNotEmpty) ...[
                      _SectionHeader('Your Mantra', theme: theme),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colors.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colors.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '"${profile.mantra}"',
                          style: TextStyle(
                            color: theme.colors.textPrimary,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _showEditSheet(context, profile, ref),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text(
                          'Edit Profile',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colors.surfacePrimary,
                          foregroundColor: theme.colors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const Scaffold(body: WrappedScreen()),
                          ),
                        ),
                        icon: const Icon(
                          Icons.auto_awesome_mosaic_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Debug: Show My Wrapped',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colors.accent,
                          side: BorderSide(color: theme.colors.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MigrateFitPointsTile(theme: theme),
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

  void _showEditGoals(
    BuildContext context,
    UserProfile profile,
    WidgetRef ref,
  ) {
    final theme = ThemeManager.instance.activeTheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGoalsSheet(profile: profile, ref: ref, theme: theme),
    );
  }

  void _showEditSheet(
    BuildContext context,
    UserProfile profile,
    WidgetRef ref,
  ) {
    final theme = ThemeManager.instance.activeTheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditProfileSheet(profile: profile, ref: ref, theme: theme),
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
    const map = {
      'both': 'Macros + Gym',
      'macros': 'Macros Only',
      'gym': 'Gym Only',
    };
    return map[use] ?? use;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────
// MANUAL MIGRATION TILE
// ─────────────────────────────────────────────
class _MigrateFitPointsTile extends ConsumerStatefulWidget {
  final dynamic theme;
  const _MigrateFitPointsTile({required this.theme});

  @override
  ConsumerState<_MigrateFitPointsTile> createState() =>
      _MigrateFitPointsTileState();
}

class _MigrateFitPointsTileState extends ConsumerState<_MigrateFitPointsTile> {
  FitPointsRecord? _detectedGuestRecord;
  bool _migrating = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final data = await LocalNutritionService.getFitPointsRecord();
    if (mounted) {
      setState(() {
        _detectedGuestRecord = data != null
            ? FitPointsRecord.fromJson(data)
            : null;
      });
    }
  }

  Future<void> _doMigrate() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null || _detectedGuestRecord == null) return;

    setState(() => _migrating = true);
    try {
      final fpService = FitPointsService();
      final accountFP = await fpService.getRecord(user.uid, false);

      final merged = fpService.migrateGuestToAccount(
        guestRecord: _detectedGuestRecord!,
        accountRecord: accountFP,
      );

      await fpService.saveRecord(merged);
      await LocalNutritionService.clearAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Merged ${_detectedGuestRecord!.lifetimePoints.toInt()} FP into your account!',
            ),
          ),
        );
      }
      await _check();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Recovery failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_detectedGuestRecord == null || ref.watch(isGuestProvider))
      return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.theme.colors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.theme.colors.accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: widget.theme.colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Found ${_detectedGuestRecord!.lifetimePoints.toInt()} un-synced FitPoints from your guest session.',
                  style: TextStyle(
                    color: widget.theme.colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _migrating ? null : _doMigrate,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.theme.colors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _migrating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Sync FitPoints Now'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACCOUNT CARD
// ─────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final UserProfile profile;
  final dynamic theme;
  const _AccountCard({required this.profile, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colors.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colors.accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colors.accent,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BMI: ${profile.bmi.toStringAsFixed(1)} • ${profile.bmiCategory}',
                  style: TextStyle(
                    color: theme.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Anonymous Account',
                  style: TextStyle(
                    color: theme.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
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
  final dynamic theme;
  const _StatsRow({required this.profile, required this.theme});

  @override
  Widget build(BuildContext context) {
    final toGo = (profile.goalWeight - profile.weight).abs();
    final isLosing = profile.goalWeight < profile.weight;

    return Row(
      children: [
        _StatTile(
          label: isLosing ? 'To Lose' : 'To Gain',
          value: '${toGo.toStringAsFixed(1)} kg',
          color: theme.colors.accent,
          theme: theme,
        ),
        const SizedBox(width: 12),
        _StatTile(
          label: 'Daily Calories',
          value: '${profile.dynamicCalories}',
          color: Colors.orangeAccent,
          theme: theme,
        ),
        const SizedBox(width: 12),
        _StatTile(
          label: 'Protein Goal',
          value: '${profile.dynamicProtein}g',
          color: Colors.blueAccent,
          theme: theme,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final dynamic theme;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: theme.colors.textSecondary, fontSize: 11),
            ),
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
  final dynamic theme;
  const _MacroGoalRow({required this.profile, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MacroTile(
          'Protein',
          '${profile.dynamicProtein}g',
          Colors.blueAccent,
          theme,
        ),
        const SizedBox(width: 10),
        _MacroTile(
          'Carbs',
          '${profile.dynamicCarbs}g',
          Colors.orangeAccent,
          theme,
        ),
        const SizedBox(width: 10),
        _MacroTile(
          'Fats',
          '${profile.dynamicFats}g',
          Colors.purpleAccent,
          theme,
        ),
        const SizedBox(width: 10),
        _MacroTile(
          'Calories',
          '${profile.dynamicCalories}',
          theme.colors.accent,
          theme,
        ),
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final dynamic theme;
  final VoidCallback? onTap;
  const _MacroTile(this.label, this.value, this.color, this.theme, {this.onTap});

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
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: theme.colors.textSecondary,
                  fontSize: 10,
                ),
              ),
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
  final dynamic theme;
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colors.surfacePrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: theme.colors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: theme.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
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
  final dynamic theme;
  const _EditProfileSheet({
    required this.profile,
    required this.ref,
    required this.theme,
  });

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
    _goalWeightCtrl = TextEditingController(
      text: widget.profile.goalWeight.toString(),
    );
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

    final isGuest = widget.ref.read(isGuestProvider);
    if (isGuest) {
      await LocalNutritionService.saveProfile(updated);
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .update(updated.toMap());
    }
    widget.ref.invalidate(userProfileProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      decoration: BoxDecoration(
        color: widget.theme.colors.backgroundPrimary,
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
                  color: widget.theme.colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit Profile',
              style: TextStyle(
                color: widget.theme.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            _EditField(
              label: 'Name',
              controller: _nameCtrl,
              numeric: false,
              theme: widget.theme,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _EditField(
                    label: 'Age',
                    controller: _ageCtrl,
                    theme: widget.theme,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _EditField(
                    label: 'Height (cm)',
                    controller: _heightCtrl,
                    theme: widget.theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _EditField(
                    label: 'Current Weight (kg)',
                    controller: _weightCtrl,
                    theme: widget.theme,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _EditField(
                    label: 'Goal Weight (kg)',
                    controller: _goalWeightCtrl,
                    theme: widget.theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EditField(
              label: 'Your Mantra',
              controller: _mantraCtrl,
              numeric: false,
              theme: widget.theme,
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Gender',
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _gender = v!),
              theme: widget.theme,
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
              theme: widget.theme,
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
              theme: widget.theme,
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
              theme: widget.theme,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.colors.accent,
                  foregroundColor: widget.theme.colors.backgroundPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? CircularProgressIndicator(
                        color: widget.theme.colors.backgroundPrimary,
                        strokeWidth: 2,
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;
  final dynamic theme;
  const _EditField({
    required this.label,
    required this.controller,
    this.numeric = true,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.colors.textPrimary),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.colors.textSecondary),
        filled: true,
        fillColor: theme.colors.surfacePrimary,
        // Issue 2: proper contentPadding so label + value don't overlap/clip
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colors.accent, width: 1.5),
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
  final dynamic theme;
  const _SectionHeader(this.title, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: theme.colors.textPrimary,
        fontWeight: FontWeight.w900,
        fontSize: 16,
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final dynamic theme;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: theme.colors.surfacePrimary,
          style: TextStyle(color: theme.colors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colors.surfacePrimary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
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
  final dynamic theme;
  const _EditGoalsSheet({
    required this.profile,
    required this.ref,
    required this.theme,
  });

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
    _calsCtrl = TextEditingController(
      text: widget.profile.dynamicCalories.toString(),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _calsCtrl.dispose();
    super.dispose();
  }

  Map<String, int> _computeMacros(int targetCals) {
    final p = widget.profile;
    double proteinMult = (p.appUse == 'gym' || p.appUse == 'both') ? 2.0 : 1.6;
    if (p.dietType == 'nonveg') proteinMult += 0.1;
    final protein = (p.weight * proteinMult).round().clamp(100, 300);
    final fats = ((targetCals * 0.25) / 9).round();
    final carbs = ((targetCals - protein * 4 - fats * 9) / 4).round().clamp(
      50,
      500,
    );
    return {
      'calories': targetCals,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final finalCals = _tabCtrl.index == 0 ? _manualCals : _paceCals;
    final m = _computeMacros(finalCals);

    final isGuest = widget.ref.read(isGuestProvider);
    if (isGuest) {
      final updated = widget.profile.copyWith(
        dynamicCalories: m['calories'],
        dynamicProtein: m['protein'],
        dynamicCarbs: m['carbs'],
        dynamicFats: m['fats'],
        goalPace: _pace,
      );
      await LocalNutritionService.saveProfile(updated);
    } else {
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
    }
    widget.ref.invalidate(userProfileProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final p = widget.profile;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      decoration: BoxDecoration(
        color: widget.theme.colors.backgroundPrimary,
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
                  color: widget.theme.colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit Goals',
              style: TextStyle(
                color: widget.theme.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${UserProfile.paceLabel(p.goalPace)} pace  •  ${p.dynamicCalories} kcal/day',
              style: TextStyle(
                color: widget.theme.colors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: widget.theme.colors.accent,
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              labelColor: widget.theme.colors.accent,
              unselectedLabelColor: widget.theme.colors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Manual'),
                Tab(text: 'By Pace'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Manual tab ────────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Issue 2: Fixed Target Cal field — proper height & padding
                      TextField(
                        controller: _calsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: widget.theme.colors.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Target Calories',
                          suffixText: 'kcal/day',
                          suffixStyle: TextStyle(
                            color: widget.theme.colors.textSecondary,
                          ),
                          labelStyle: TextStyle(
                            color: widget.theme.colors.textSecondary,
                          ),
                          filled: true,
                          fillColor: widget.theme.colors.surfacePrimary,
                          // Key fix: explicit contentPadding keeps text vertically
                          // centered and prevents the label from being clipped
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: widget.theme.colors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (v) => setState(
                          () => _manualCals = int.tryParse(v) ?? _manualCals,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_manualCals > 0) ...[
                        Text(
                          'Auto macro split:',
                          style: TextStyle(
                            color: widget.theme.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (_) {
                            final m = _computeMacros(_manualCals);
                            return Row(
                              children: [
                                _GoalChip(
                                  'Protein',
                                  '${m['protein']}g',
                                  Colors.blueAccent,
                                  widget.theme,
                                ),
                                const SizedBox(width: 8),
                                _GoalChip(
                                  'Carbs',
                                  '${m['carbs']}g',
                                  Colors.orangeAccent,
                                  widget.theme,
                                ),
                                const SizedBox(width: 8),
                                _GoalChip(
                                  'Fats',
                                  '${m['fats']}g',
                                  Colors.purpleAccent,
                                  widget.theme,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),

                  // ── Pace tab ──────────────────────────────────────────
                  GoalPaceSlider(
                    weight: p.weight,
                    goalWeight: p.goalWeight,
                    tdee: p.tdee,
                    initialPace: _pace,
                    onPaceChanged: (pace) => setState(() => _pace = pace),
                    onCaloriesChanged: (cals) =>
                        setState(() => _paceCals = cals),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.colors.accent,
                  foregroundColor: widget.theme.colors.backgroundPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? CircularProgressIndicator(
                        color: widget.theme.colors.backgroundPrimary,
                        strokeWidth: 2,
                      )
                    : const Text(
                        'Save Goals',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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

class _GoalChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final dynamic theme;
  const _GoalChip(this.label, this.value, this.color, this.theme);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: theme.colors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}
