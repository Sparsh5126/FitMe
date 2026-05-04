import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_profile.dart';
import '../../dashboard/providers/user_provider.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/log_sheet.dart';
import '../widgets/smart_logger_sheet.dart';
import '../../nutrition/screens/macro_detail_screen.dart';
import '../../nutrition/screens/quantity_selection_screen.dart';
import '../../streak/screens/streak_screen.dart';
import '../models/food_item.dart';
import '../../insights/screens/diet_analysis_screen.dart';
import '../../insights/screens/diet_plan_screen.dart';
import '../../recipes/screens/recipes_screen.dart';

class _DismissedMealsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void add(String id) => state = {...state, id};
}

final dismissedMealsProvider =
    NotifierProvider<_DismissedMealsNotifier, Set<String>>(
        _DismissedMealsNotifier.new);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _activePage = 0;
  double _logoOffset = 0.0;

  void _onLogoDragUpdate(DragUpdateDetails details) {
    setState(() {
      _logoOffset += details.primaryDelta! / 200;
      _logoOffset = _logoOffset.clamp(0.0, 1.0);
    });
  }

  void _onLogoDragEnd(DragEndDetails details) {
    if (_logoOffset > 0.5) {
      setState(() {
        _logoOffset = 1.0;
        _activePage = 1;
      });
      HapticFeedback.mediumImpact();
    } else {
      setState(() {
        _logoOffset = 0.0;
        _activePage = 0;
      });
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final mealsAsync = ref.watch(nutritionProvider);
    final dismissedIds = ref.watch(dismissedMealsProvider);
    final meals =
        (mealsAsync.value ?? []).where((m) => !dismissedIds.contains(m.id)).toList();
    final selectedDate = ref.watch(selectedDateProvider);

    final streakAsync = ref.watch(streakProvider);
    final debugLevel = ref.watch(debugStreakLevelProvider);
    final currentStreakLevel = debugLevel ?? streakAsync.value?.level ?? 0;
    // Issue 6: streak count for badge next to dumbbell
    final streakCount = streakAsync.value?.currentStreak ?? 0;

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

        int totalCals = 0, totalPro = 0, totalCarbs = 0, totalFats = 0, totalWater = 0;
        for (final m in meals) {
          totalCals += m.calories;
          totalPro += m.protein;
          totalCarbs += m.carbs;
          totalFats += m.fats;
          if (m.name.toLowerCase() == 'water') {
            totalWater += m.consumedAmount.toInt();
          }
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: SizedBox(
                    height: 50,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ── Issue 6: Streak icon + count ──────────
                        Positioned(
                          right: 0,
                          child: Opacity(
                            opacity: (1 - _logoOffset).clamp(0.0, 1.0),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const StreakScreen()));
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Streak count shown to the left of dumbbell
                                  if (streakCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Text(
                                        '$streakCount',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: 75,
                                    height: 35,
                                    child: FitMe3DModel(
                                      key: ValueKey(
                                          'home_streak_$currentStreakLevel'),
                                      level: currentStreakLevel,
                                      angleX: -0.15,
                                      angleY: -0.35,
                                      interactive: false,
                                      autoRotate: true,
                                      drawText: false,
                                      drawWireframe: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // ── FitMe draggable logo ──────────────────
                        Align(
                          alignment: Alignment.lerp(Alignment.centerLeft,
                                  Alignment.centerRight, _logoOffset) ??
                              Alignment.centerLeft,
                          child: GestureDetector(
                            onHorizontalDragUpdate: _onLogoDragUpdate,
                            onHorizontalDragEnd: _onLogoDragEnd,
                            child: Container(
                              color: Colors.transparent,
                              child: Column(
                                crossAxisAlignment: _logoOffset < 0.5
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('FitMe',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.5)),
                                  Text(
                                    _logoOffset < 0.5
                                        ? ' Exercise? →'
                                        : '← Macros? ',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _activePage == 0
                        ? _FoodPage(
                            profile: profile,
                            selectedDate: selectedDate,
                            totalCals: totalCals,
                            totalPro: totalPro,
                            totalCarbs: totalCarbs,
                            totalFats: totalFats,
                            totalWater: totalWater,
                            meals: meals,
                          )
                        : const _ExercisePage(),
                  ),
                ),
              ],
            ),
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
  final List meals;

  const _FoodPage({
    required this.profile,
    required this.selectedDate,
    required this.totalCals,
    required this.totalPro,
    required this.totalCarbs,
    required this.totalFats,
    required this.totalWater,
    required this.meals,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleMeals =
        meals.where((m) => m.name.toLowerCase() != 'water').toList();
    final dateLabel = _formatDate(selectedDate);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isAtToday = !selectedDate.isBefore(DateTime(now.year, now.month, now.day)) &&
        selectedDate.isBefore(tomorrow);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Issue 5: Date Navigation ─────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left arrow (previous day)
                _DateNavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedDateProvider.notifier).state =
                        selectedDate.subtract(const Duration(days: 1));
                  },
                ),
                // Date label – tapping opens calendar picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(now.year - 2),
                      lastDate: now,
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: AppTheme.accent,
                            surface: AppTheme.surface,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: AppTheme.background,
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      ref.read(selectedDateProvider.notifier).state = picked;
                    }
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        color: isAtToday ? Colors.white : AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                // Right arrow (next day, capped at today)
                _DateNavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: () {
                    if (!isAtToday) {
                      HapticFeedback.selectionClick();
                      ref.read(selectedDateProvider.notifier).state =
                          selectedDate.add(const Duration(days: 1));
                    }
                  },
                  muted: isAtToday,
                ),
              ],
            ),
          ),

          // ── Issue 4: Rings pushed slightly up ───────────────────
          const SizedBox(height: 6),

          Column(
            children: [
              // Big calorie ring
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MacroDetailScreen())),
                child: CircularPercentIndicator(
                  radius: 80.0,
                  lineWidth: 12.0,
                  animation: true,
                  animateFromLastPercent: true,
                  percent: (totalCals / profile.dynamicCalories).clamp(0.0, 1.0),
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$totalCals',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('/ ${profile.dynamicCalories} kcal',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      const Text('tap for details',
                          style: TextStyle(
                              fontSize: 9, color: AppTheme.textSecondary)),
                    ],
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: totalCals > profile.dynamicCalories
                      ? Colors.redAccent
                      : Colors.white,
                  backgroundColor: AppTheme.surface,
                ),
              ),

              const SizedBox(height: 12),

              // 4 smaller rings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MacroDetailScreen())),
                    child: _SmallRing(
                        label: 'Protein',
                        current: totalPro,
                        goal: profile.dynamicProtein,
                        color: Colors.blueAccent),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MacroDetailScreen())),
                    child: _SmallRing(
                        label: 'Carbs',
                        current: totalCarbs,
                        goal: profile.dynamicCarbs,
                        color: Colors.orangeAccent),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MacroDetailScreen())),
                    child: _SmallRing(
                        label: 'Fats',
                        current: totalFats,
                        goal: profile.dynamicFats,
                        color: Colors.purpleAccent),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(foodActionsProvider).logFood(FoodItem(
                        id:
                            '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}',
                        name: 'Water',
                        calories: 0,
                        protein: 0,
                        carbs: 0,
                        fats: 0,
                        consumedAmount: 250,
                        consumedUnit: 'ml',
                        dateString: FoodItem.dateFor(selectedDate),
                      ));
                    },
                    child: _SmallRing(
                        label: 'Water',
                        current: totalWater,
                        goal: 2500,
                        color: Colors.cyanAccent,
                        unit: 'ml'),
                  ),
                ],
              ),
            ],
          ),

          // ── Issue 4: More breathing room before SMART LOGGER label ──
          const SizedBox(height: 22),

          // ── SMART LOGGER ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(left: 20),
            child: Text('SMART LOGGER',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 76,
            child: PageView(
              physics: const BouncingScrollPhysics(),
              children: [
                Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      SmartLoggerSheet.show(context);
                    },
                    child: Container(
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                              child: Text('Type or Speak to log food...',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14))),
                          Icon(Icons.mic_rounded,
                              color: AppTheme.accent.withValues(alpha: 0.8)),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionIcon(
                        icon: Icons.restaurant_menu_rounded,
                        label: 'Diet Plan',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DietPlanScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionIcon(
                        icon: Icons.analytics_rounded,
                        label: 'Analyse Diet',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DietAnalysisScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionIcon(
                        icon: Icons.menu_book_rounded,
                        label: 'Recipes',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RecipesScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Center(
              child: Text('← Explore More! →',
                  style:
                      TextStyle(fontSize: 10, color: AppTheme.textSecondary))),

          const SizedBox(height: 16),

          // ── LOGGED FOOD ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 12),
            child: Text('Logged Food',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),

          if (visibleMeals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                    'No meals logged yet.\nTap the + button to start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleMeals.length,
              itemBuilder: (context, index) {
                final meal = visibleMeals[index];
                return _LoggedMealTile(meal: meal);
              },
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATE NAV BUTTON
// ─────────────────────────────────────────────
class _DateNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;
  const _DateNavBtn({required this.icon, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Icon(icon,
            color: muted
                ? AppTheme.textSecondary.withOpacity(0.3)
                : AppTheme.textSecondary,
            size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EXERCISE PAGE
// ─────────────────────────────────────────────
class _ExercisePage extends StatelessWidget {
  const _ExercisePage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.fitness_center_rounded,
              color: AppTheme.textSecondary, size: 48),
          SizedBox(height: 12),
          Text('Exercise page coming soon.',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
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
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: (current / goal).clamp(0.0, 1.0)),
          builder: (context, value, child) {
            return CircularPercentIndicator(
              radius: 38.0,
              lineWidth: 6.0,
              animation: false,
              percent: value,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$current$unit',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOver ? Colors.redAccent : Colors.white)),
                  Text('/$goal$unit',
                      style: const TextStyle(
                          fontSize: 9, color: AppTheme.textSecondary)),
                ],
              ),
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: ringColor,
              backgroundColor: AppTheme.surface,
            );
          },
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold)),
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

  const _ActionIcon(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
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
      onDismissed: (_) {
        ref.read(dismissedMealsProvider.notifier).add(meal.id);
        ref.read(foodActionsProvider).deleteFood(meal.id);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    QuantitySelectionScreen(baseFood: meal, editItemId: meal.id))),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (meal.isAiLogged == true)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Text('🪄', style: TextStyle(fontSize: 14)),
                          ),
                        Expanded(
                          child: Text(meal.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  Text('${meal.calories} Cal',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              Text('P:${meal.protein}g C:${meal.carbs}g F:${meal.fats}g',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}