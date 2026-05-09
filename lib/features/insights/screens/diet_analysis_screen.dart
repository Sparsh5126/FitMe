import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../dashboard/providers/user_provider.dart';
import '../../nutrition/models/food_item.dart';
import '../../nutrition/repositories/nutrition_repository.dart';
import '../services/ai_usage_service.dart';
import '../services/diet_analysis_service.dart';
import '../../fitpoints/services/fitpoints_service.dart';
import '../../fitpoints/providers/fitpoints_provider.dart';
import '../../fitpoints/models/fitpoints_models.dart';

// ─────────────────────────────────────────────
// AI usage helpers — delegated to AiUsageService
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// AI DIET ANALYSIS NOTIFIER
// ─────────────────────────────────────────────
class AiAnalysisNotifier extends Notifier<AsyncValue<DietAnalysisResult?>> {
  @override
  AsyncValue<DietAnalysisResult?> build() => const AsyncValue.data(null);

  Future<void> generate() async {
    state = const AsyncValue.loading();
    try {
      final profile = ref.read(userProfileProvider).value;
      if (profile == null) {
        throw Exception('User profile not found. Please complete profile.');
      }

      // Consume one AI credit
      final allowed = await AiUsageService.consume();
      if (!allowed) {
        throw Exception('Daily AI limit reached ($kAiDailyLimit/day). Try again tomorrow.');
      }

      final repo = NutritionRepository();
      final now = DateTime.now();
      final List<FoodItem> allLogs = [];

      for (int i = 0; i < 7; i++) {
        final dateStr = FoodItem.dateFor(now.subtract(Duration(days: i)));
        final logs = await repo.getLogsForDate(dateStr);
        allLogs.addAll(logs);
      }

      if (allLogs.isEmpty) {
        throw Exception(
            'No food logged in the last 7 days. Start logging to get insights!');
      }

      final result = await DietAnalysisService.analyze7Days(allLogs, profile);
      if (result == null) {
        throw Exception('AI could not generate insights at this time.');
      }

      state = AsyncValue.data(result);

      // Award FitPoints for completing diet analysis
      final service = ref.read(fitPointsServiceProvider);
      final fpRecord = await service.getRecord(profile.uid, false);
      
      final award = service.awardPoints(
        userId: profile.uid,
        action: FitPointAction.completeDietAnalysis,
        record: fpRecord,
        todayTransactions: [], // Service handles absolute caps internally
      );

      if (award.awarded) {
        final updatedRecord = service.applyAward(record: fpRecord, result: award);
        await service.saveRecord(updatedRecord);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final aiAnalysisProvider =
    NotifierProvider<AiAnalysisNotifier, AsyncValue<DietAnalysisResult?>>(
        AiAnalysisNotifier.new);

// ─────────────────────────────────────────────
// UI SCREEN
// ─────────────────────────────────────────────
class DietAnalysisScreen extends ConsumerWidget {
  const DietAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final analysisState = ref.watch(aiAnalysisProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Analyse Diet', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: isGuest
          ? _GuestLockView(feature: 'Diet Analysis')
          : ListView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 24),
                    SizedBox(width: 10),
                    Text('7-Day AI Review',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                    'Gemini will analyze your exact logs over the last 7 days against your personal diet goals to find patterns, missing nutrients, and performance gaps.',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5)),
                const SizedBox(height: 8),
                // AI usage counter
                _AiUsageChip(),
                const SizedBox(height: 16),

                if (analysisState is AsyncLoading)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                        color: AppTheme.surface, borderRadius: BorderRadius.circular(20)),
                    child: const Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.accent),
                        SizedBox(height: 20),
                        Text('Analyzing 7-day logs...',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else if (analysisState is AsyncError)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${analysisState.error}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  )
                else if (analysisState.value == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => ref.read(aiAnalysisProvider.notifier).generate(),
                      icon: const Icon(Icons.analytics_rounded, size: 20),
                      label: const Text('Generate 7-Day Analysis',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  )
                else
                  Column(children: [
                    _InsightCard(
                        icon: Icons.fitness_center_rounded,
                        title: 'Protein Gaps',
                        text: analysisState.value!.proteinGaps,
                        color: Colors.blueAccent),
                    _InsightCard(
                        icon: Icons.local_fire_department_rounded,
                        title: 'Calorie Trends',
                        text: analysisState.value!.calorieTrends,
                        color: Colors.orangeAccent),
                    _InsightCard(
                        icon: Icons.schedule_rounded,
                        title: 'Meal Timing',
                        text: analysisState.value!.mealTiming,
                        color: Colors.tealAccent),
                    _InsightCard(
                        icon: Icons.fastfood_rounded,
                        title: 'Junk Frequency',
                        text: analysisState.value!.junkFrequency,
                        color: Colors.redAccent),
                    _InsightCard(
                        icon: Icons.health_and_safety_rounded,
                        title: 'Micronutrient Warnings',
                        text: analysisState.value!.micronutrientWarnings,
                        color: Colors.greenAccent),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => ref.read(aiAnalysisProvider.notifier).generate(),
                      icon: const Icon(Icons.refresh_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      label: const Text('Recalculate Analysis',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    )
                  ]),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// AI USAGE CHIP
// ─────────────────────────────────────────────
class _AiUsageChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: AiUsageService.getRemainingUses(),
      builder: (context, snap) {
        final remaining = snap.data ?? kAiDailyLimit;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 14),
              const SizedBox(width: 6),
              Text(
                '$remaining/$kAiDailyLimit AI uses remaining today',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// GUEST LOCK VIEW
// ─────────────────────────────────────────────
class _GuestLockView extends StatelessWidget {
  final String feature;
  const _GuestLockView({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_rounded, color: AppTheme.accent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    '$feature requires an account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign in or create a free account to unlock AI-powered diet analysis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Sign In / Create Account',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _InsightCard(
      {required this.icon,
      required this.title,
      required this.text,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 14),
        Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.5)),
      ]),
    );
  }
}