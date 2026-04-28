import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../core/theme/app_theme.dart';
import '../nutrition/widgets/smart_logger_sheet.dart';
import '../nutrition/widgets/smart_food_card.dart';
import '../nutrition/providers/nutrition_provider.dart';
import '../nutrition/screens/food_details_screen.dart';
import '../nutrition/screens/quantity_selection_screen.dart';
import 'providers/user_provider.dart';
import '../../core/models/user_profile.dart'; 
import '../profile/screens/profile_screen.dart'; 
import '../streak/screens/streak_screen.dart'; // Gives access to FitMe3DModel

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedMealsAsync = ref.watch(nutritionProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final streakAsync = ref.watch(streakProvider);
    
    // Listens to your Bug Icon debug state!
    final debugLevel = ref.watch(debugStreakLevelProvider);
    final currentStreakLevel = debugLevel ?? streakAsync.value?.level ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: userProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (err, stack) => Center(child: Text('Error loading profile: $err', style: const TextStyle(color: Colors.redAccent))),
        data: (userProfile) {
          if (userProfile == null) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }

          final loggedMeals = loggedMealsAsync.value ?? [];
          int totalCals = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
          for (var meal in loggedMeals) {
            totalCals += meal.calories;
            totalPro += meal.protein;
            totalCarb += meal.carbs;
            totalFat += meal.fats;
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: DashboardHeaderDelegate(
                  totalCals: totalCals,
                  totalPro: totalPro,
                  totalCarb: totalCarb,
                  totalFat: totalFat,
                  goalCals: userProfile.dailyCalories,
                  goalPro: userProfile.dailyProtein,
                  goalCarb: userProfile.dailyCarbs,
                  goalFat: userProfile.dailyFats,
                  streakLevel: currentStreakLevel, 
                ),
              ),

              if (loggedMeals.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    height: 300,
                    alignment: Alignment.center,
                    child: const Text(
                      "No meals logged yet.\nTap + to start.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final meal = loggedMeals[index];
                        return SmartFoodCard(
                          id: meal.id,
                          foodName: meal.name,
                          calories: meal.calories,
                          protein: meal.protein,
                          carbs: meal.carbs,
                          fats: meal.fats,
                          consumedAmount: meal.consumedAmount,
                          consumedUnit: meal.consumedUnit,
                          onDetailsTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => FoodDetailsScreen(food: meal)));
                          },
                          onEditDoubleTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuantitySelectionScreen(
                                  baseFood: meal,
                                  editItemId: meal.id,
                                ),
                              ),
                            );
                          },
                          onDeleteSwipe: () => ref.read(foodActionsProvider).deleteFood(meal.id),
                        );
                      },
                      childCount: loggedMeals.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        onPressed: () => SmartLoggerSheet.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight = 360.0;
  final double collapsedHeight = 120.0;

  final int totalCals;
  final int totalPro;
  final int totalCarb;
  final int totalFat;
  final int goalCals;
  final int goalPro;
  final int goalCarb;
  final int goalFat;
  final int streakLevel;

  DashboardHeaderDelegate({
    required this.totalCals,
    required this.totalPro,
    required this.totalCarb,
    required this.totalFat,
    required this.goalCals,
    required this.goalPro,
    required this.goalCarb,
    required this.goalFat,
    required this.streakLevel,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double scrollPercentage = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final double expandOpacity = (1.0 - (scrollPercentage * 2)).clamp(0.0, 1.0);
    final double collapseOpacity = ((scrollPercentage - 0.5) * 2).clamp(0.0, 1.0);

    bool isCalOver = totalCals > goalCals;
    Color calRingColor = isCalOver ? Colors.redAccent : AppTheme.accent;
    Color calTextColor = isCalOver ? Colors.redAccent : Colors.white;

    return ClipRect(
      child: Container(
        color: AppTheme.background,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (expandOpacity > 0.0)
                Opacity(
                  opacity: expandOpacity,
                  child: Align(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('FitMe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
                              
                              // ── THE TRUE 3D ICON EMBEDDED IN DASHBOARD ──
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const StreakScreen()));
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  color: Colors.transparent, 
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                  child: SizedBox(
                                    width: 75, // Wide enough to see the plates
                                    height: 35,
                                    child: FitMe3DModel(
                                      key: ValueKey('dashboard_streak_$streakLevel'), // Forces hard redraw on level change
                                      level: streakLevel,
                                      angleX: -0.15, // Slight top-down tilt so it looks 3D
                                      angleY: -0.35, // Tilted to show the 3D plates clearly
                                      interactive: false,
                                      drawText: false, 
                                      drawWireframe: true, 
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CircularPercentIndicator(
                            radius: 70.0,
                            lineWidth: 10.0,
                            animation: true,
                            animateFromLastPercent: true,
                            percent: (totalCals / goalCals).clamp(0.0, 1.0),
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("$totalCals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: calTextColor)),
                                Text("/ $goalCals", style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                            circularStrokeCap: CircularStrokeCap.round,
                            progressColor: calRingColor,
                            backgroundColor: AppTheme.surface,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSmallWheel("Protein", totalPro, goalPro, Colors.blueAccent),
                              _buildSmallWheel("Carbs", totalCarb, goalCarb, Colors.orangeAccent),
                              _buildSmallWheel("Fats", totalFat, goalFat, Colors.purpleAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (collapseOpacity > 0.0)
                Opacity(
                  opacity: collapseOpacity,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMiniBar("Cals", totalCals, goalCals, AppTheme.accent, isCal: true),
                          _buildMiniBar("Pro", totalPro, goalPro, Colors.blueAccent),
                          _buildMiniBar("Carb", totalCarb, goalCarb, Colors.orangeAccent),
                          _buildMiniBar("Fat", totalFat, goalFat, Colors.purpleAccent),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallWheel(String label, int current, int goal, Color defaultColor) {
    bool isOver = current > goal;
    Color ringColor = isOver ? Colors.redAccent : defaultColor;
    Color textColor = isOver ? Colors.redAccent : Colors.white;

    return Column(
      children: [
        CircularPercentIndicator(
          radius: 36.0,
          lineWidth: 6.0,
          animation: true,
          animateFromLastPercent: true,
          percent: (current / goal).clamp(0.0, 1.0),
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("${current}g", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
              Text("/${goal}g", style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ],
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: ringColor,
          backgroundColor: AppTheme.surface,
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMiniBar(String label, int current, int goal, Color defaultColor, {bool isCal = false}) {
    bool isOver = current > goal;
    Color barColor = isOver ? Colors.redAccent : defaultColor;
    Color textColor = isOver ? Colors.redAccent : Colors.white;

    final String valueText = isCal ? "$current / $goal" : "${current}g / ${goal}g";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(valueText, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        LinearPercentIndicator(
          width: 70.0,
          lineHeight: 6.0,
          percent: (current / goal).clamp(0.0, 1.0),
          animation: true,
          animateFromLastPercent: true,
          barRadius: const Radius.circular(8),
          progressColor: barColor,
          backgroundColor: AppTheme.surface,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant DashboardHeaderDelegate oldDelegate) {
    return oldDelegate.totalCals != totalCals ||
        oldDelegate.totalPro != totalPro ||
        oldDelegate.totalCarb != totalCarb ||
        oldDelegate.totalFat != totalFat ||
        oldDelegate.goalCals != goalCals ||
        oldDelegate.streakLevel != streakLevel;
  }
}