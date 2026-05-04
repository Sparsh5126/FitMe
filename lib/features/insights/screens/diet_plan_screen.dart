import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/providers/user_provider.dart';
import '../services/diet_plan_service.dart';

class DietPlanNotifier extends Notifier<AsyncValue<List<DietMealPlan>?>> {
  @override
  AsyncValue<List<DietMealPlan>?> build() => const AsyncValue.data(null);

  Future<void> generate(String planType, String lifestyle, String budget) async {
    state = const AsyncValue.loading();
    try {
      final profile = ref.read(userProfileProvider).value;
      if (profile == null) throw Exception('Profile not loaded.');

      final plan = await DietPlanService.generatePlan(
        profile: profile,
        planType: planType,
        lifestyle: lifestyle,
        budget: budget,
      );

      if (plan == null || plan.isEmpty) {
        throw Exception('Failed to generate plan. Please try again.');
      }

      state = AsyncValue.data(plan);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final dietPlanProvider = NotifierProvider<DietPlanNotifier, AsyncValue<List<DietMealPlan>?>>(DietPlanNotifier.new);

class DietPlanScreen extends ConsumerStatefulWidget {
  const DietPlanScreen({super.key});

  @override
  ConsumerState<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends ConsumerState<DietPlanScreen> {
  String _selectedType = 'Vegetarian';
  String _selectedLifestyle = 'Student';
  String _selectedBudget = 'Medium';

  final List<String> _types = ['Vegetarian', 'Non Vegetarian', 'Keto', 'High Protein', 'Fat Loss', 'Lean Bulk'];
  final List<String> _lifestyles = ['Student', 'Working professional', 'Business owner'];
  final List<String> _budgets = ['Low', 'Medium', 'High'];

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(dietPlanProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Smart Diet Planner', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (planState.value != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.read(dietPlanProvider.notifier).reset(),
            )
        ],
      ),
      body: planState.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(error: e.toString()),
        data: (plan) {
          if (plan == null) return _buildConfigurationForm();
          return _buildGeneratedPlan(plan);
        },
      ),
    );
  }

  Widget _buildConfigurationForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text('Design Your Plan', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Customize your AI-generated meal plan based on your preferences, schedule, and budget.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),

        _SectionTitle('Plan Type'),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _types.map((t) => _ChoiceChip(
            label: t, isSelected: _selectedType == t,
            onTap: () => setState(() => _selectedType = t),
          )).toList(),
        ),
        const SizedBox(height: 28),

        _SectionTitle('Lifestyle / Schedule'),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _lifestyles.map((l) => _ChoiceChip(
            label: l, isSelected: _selectedLifestyle == l,
            onTap: () => setState(() => _selectedLifestyle = l),
          )).toList(),
        ),
        const SizedBox(height: 28),

        _SectionTitle('Budget'),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _budgets.map((b) => _ChoiceChip(
            label: b, isSelected: _selectedBudget == b,
            onTap: () => setState(() => _selectedBudget = b),
          )).toList(),
        ),
        const SizedBox(height: 48),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => ref.read(dietPlanProvider.notifier).generate(_selectedType, _selectedLifestyle, _selectedBudget),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate My Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildGeneratedPlan(List<DietMealPlan> plan) {
    int totalCals = plan.fold(0, (sum, m) => sum + m.calories);
    int totalPro = plan.fold(0, (sum, m) => sum + m.protein);

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.accent.withOpacity(0.3))),
          child: Column(
            children: [
              const Text('Target Met!', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MacroStat('$totalCals', 'kcal'),
                  _MacroStat('${totalPro}g', 'Protein'),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...plan.map((meal) => _MealPlanCard(meal: meal)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
  );
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.accent : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.background : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MealPlanCard extends StatelessWidget {
  final DietMealPlan meal;
  const _MealPlanCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(meal.mealName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(meal.time, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Text(meal.foodDescription, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroBadge('${meal.calories}', 'kcal', AppTheme.accent),
              _MacroBadge('${meal.protein}g', 'Pro', Colors.blueAccent),
              _MacroBadge('${meal.carbs}g', 'Carb', Colors.orangeAccent),
              _MacroBadge('${meal.fats}g', 'Fat', Colors.purpleAccent),
            ],
          )
        ],
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String val, label;
  final Color color;
  const _MacroBadge(this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
  ]);
}

class _MacroStat extends StatelessWidget {
  final String val, label;
  const _MacroStat(this.val, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
  ]);
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppTheme.accent),
        SizedBox(height: 24),
        Text('Crafting your perfect diet...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Crunching macros and matching your budget.', style: TextStyle(color: AppTheme.textSecondary)),
      ],
    )
  );
}

class _ErrorView extends ConsumerWidget {
  final String error;
  const _ErrorView({required this.error});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(dietPlanProvider.notifier).reset(),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surface),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    ),
  );
}