import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_profile.dart';
import '../../dashboard/providers/user_provider.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/log_sheet.dart';
import '../widgets/smart_logger_sheet.dart';
import '../../streak/screens/streak_screen.dart';
import '../../nutrition/screens/macro_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // 0 = food page, 1 = exercise page (FitMe logo slider)
  int _activePage = 0;
  DateTime _selectedDate = DateTime.now();

  void _onLogoSlide(DragUpdateDetails d) {
    if (d.delta.dx > 8 && _activePage == 0) {
      HapticFeedback.mediumImpact();
      setState(() => _activePage = 1);
    } else if (d.delta.dx < -8 && _activePage == 1) {
      HapticFeedback.mediumImpact();
      setState(() => _activePage = 0);
    }
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final meals = ref.watch(nutritionProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
      ),
      data: (profile) {
        if (profile == null) return const SizedBox();

        // Totals
        int totalCals = 0, totalPro = 0, totalCarbs = 0, totalFats = 0, totalWater = 0;
        for (final m in meals) {
          totalCals += m.calories;
          totalPro += m.protein;
          totalCarbs += m.carbs;
          totalFats += m.fats;
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: _activePage == 0
                ? _FoodPage(
                    profile: profile,
                    selectedDate: _selectedDate,
                    totalCals: totalCals,
                    totalPro: totalPro,
                    totalCarbs: totalCarbs,
                    totalFats: totalFats,
                    totalWater: totalWater,
                    onDateChanged: _changeDate,
                    onLogoSlide: _onLogoSlide,
                  )
                : _ExercisePage(onLogoSlide: _onLogoSlide),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// FOOD PAGE
// ─────────────────────────────────────────────
class _FoodPage extends ConsumerWidget {
  final UserProfile profile;
  final DateTime selectedDate;
  final int totalCals, totalPro, totalCarbs, totalFats, totalWater;
  final ValueChanged<int> onDateChanged;
  final GestureDragUpdateCallback onLogoSlide;

  const _FoodPage({
    required this.profile,
    required this.selectedDate,
    required this.totalCals,
    required this.totalPro,
    required this.totalCarbs,
    required this.totalFats,
    required this.totalWater,
    required this.onDateChanged,
    required this.onLogoSlide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(nutritionProvider);

    return Column(
      children: [
        // ── Top bar ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Streak icon
              _IconBtn(
                icon: Icons.fitness_center_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StreakScreen())),
              ),
              // Date strip
              _DateStrip(selectedDate: selectedDate, onChanged: onDateChanged),
              // FitMe logo (swipeable)
              GestureDetector(
                onHorizontalDragUpdate: onLogoSlide,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 8)],
                  ),
                  alignment: Alignment.center,
                  child: const Text('FM', style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.black, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Rings ────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => MacroDetailScreen(
              totalCals: totalCals, totalPro: totalPro,
              totalCarbs: totalCarbs, totalFats: totalFats,
              goalCals: profile.dynamicCalories, goalPro: profile.dynamicProtein,
              goalCarbs: profile.dynamicCarbs, goalFats: profile.dynamicFats,
            ),
          )),
          child: Column(
            children: [
              // Big calorie ring
              CircularPercentIndicator(
                radius: 80.0,
                lineWidth: 12.0,
                animation: true,
                animateFromLastPercent: true,
                percent: (totalCals / profile.dynamicCalories).clamp(0.0, 1.0),
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$totalCals', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('/ ${profile.dynamicCalories} kcal', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    const Text('tap for details', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  ],
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: totalCals > profile.dynamicCalories ? Colors.redAccent : AppTheme.accent,
                backgroundColor: AppTheme.surface,
              ),

              const SizedBox(height: 20),

              // 4 smaller rings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SmallRing(label: 'Protein', current: totalPro, goal: profile.dynamicProtein, color: Colors.blueAccent),
                  _SmallRing(label: 'Carbs', current: totalCarbs, goal: profile.dynamicCarbs, color: Colors.orangeAccent),
                  _SmallRing(label: 'Fats', current: totalFats, goal: profile.dynamicFats, color: Colors.purpleAccent),
                  _SmallRing(label: 'Water', current: totalWater, goal: 8, color: Colors.cyanAccent, unit: 'gl'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Action icons row ──────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionIcon(
                icon: Icons.search_rounded,
                label: 'Log',
                onTap: () => LogSheet.show(context),
              ),
              _ActionIcon(
                icon: Icons.auto_awesome_rounded,
                label: 'AI Log',
                onTap: () => SmartLoggerSheet.show(context),
              ),
              _ActionIcon(
                icon: Icons.camera_alt_rounded,
                label: 'Photo',
                onTap: () {}, // Phase 3
              ),
              _ActionIcon(
                icon: Icons.mic_rounded,
                label: 'Voice',
                onTap: () {}, // Phase 3
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Logged meals list ────────────────────
        Expanded(
          child: meals.isEmpty
              ? const Center(
                  child: Text('No meals logged yet.\nTap Log or AI Log to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: meals.length,
                  itemBuilder: (context, index) {
                    final meal = meals[index];
                    return _LoggedMealTile(meal: meal);
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// EXERCISE PAGE (placeholder — built in Phase 5)
// ─────────────────────────────────────────────
class _ExercisePage extends StatelessWidget {
  final GestureDragUpdateCallback onLogoSlide;
  const _ExercisePage({required this.onLogoSlide});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center_rounded, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 12),
          const Text('Exercise page coming soon.', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          GestureDetector(
            onHorizontalDragUpdate: onLogoSlide,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('← Swipe FM logo to go back', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATE STRIP
// ─────────────────────────────────────────────
class _DateStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<int> onChanged;

  const _DateStrip({required this.selectedDate, required this.onChanged});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final diff = selected.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onChanged(-1),
          child: const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary),
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(primary: AppTheme.accent, surface: AppTheme.surface),
                ),
                child: child!,
              ),
            );
          },
          child: Text(_label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        GestureDetector(
          onTap: () => onChanged(1),
          child: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SMALL RING
// ─────────────────────────────────────────────
class _SmallRing extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  final Color color;
  final String unit;

  const _SmallRing({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    final isOver = current > goal;
    final ringColor = isOver ? Colors.redAccent : color;

    return Column(
      children: [
        CircularPercentIndicator(
          radius: 38.0,
          lineWidth: 6.0,
          animation: true,
          animateFromLastPercent: true,
          percent: (current / goal).clamp(0.0, 1.0),
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$current$unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOver ? Colors.redAccent : Colors.white)),
              Text('/$goal$unit', style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ],
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: ringColor,
          backgroundColor: AppTheme.surface,
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ACTION ICON
// ─────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGGED MEAL TILE
// ─────────────────────────────────────────────
class _LoggedMealTile extends ConsumerWidget {
  final dynamic meal;
  const _LoggedMealTile({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(meal.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(nutritionProvider.notifier).deleteFood(meal.id),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            if (meal.isAiLogged == true)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('🪄', style: TextStyle(fontSize: 14)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${meal.protein}g P  •  ${meal.carbs}g C  •  ${meal.fats}g F',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text('${meal.calories} kcal',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
    );
  }
}