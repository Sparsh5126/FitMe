import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';

class FoodDetailsScreen extends StatelessWidget {
  final FoodItem food;

  const FoodDetailsScreen({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    // Calculate total macros to find percentages
    final totalMacros = food.protein + food.carbs + food.fats;
    final proPercent = totalMacros > 0 ? food.protein / totalMacros : 0.0;
    final carbPercent = totalMacros > 0 ? food.carbs / totalMacros : 0.0;
    final fatPercent = totalMacros > 0 ? food.fats / totalMacros : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Details', style: TextStyle(color: Colors.white, fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------
            // HERO SECTION: Food Name & Calories
            // ---------------------------------------------
            Text(
              food.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '${food.calories} kcal',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.accent),
            ),
            const SizedBox(height: 32),

            // ---------------------------------------------
            // MACRO VISUALIZATION
            // ---------------------------------------------
            const Text('Macro Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCircularMacro('Protein', '${food.protein}g', proPercent, Colors.blueAccent),
                _buildCircularMacro('Carbs', '${food.carbs}g', carbPercent, Colors.orangeAccent),
                _buildCircularMacro('Fats', '${food.fats}g', fatPercent, Colors.redAccent),
              ],
            ),
            const SizedBox(height: 40),

            // ---------------------------------------------
            // MICRO-NUTRIENTS (Mocked for now until API integration)
            // ---------------------------------------------
            const Text('Micro-Nutrients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildNutrientRow('Dietary Fiber', '4.2 g'),
                  _buildDivider(),
                  _buildNutrientRow('Total Sugars', '2.1 g'),
                  _buildDivider(),
                  _buildNutrientRow('Added Sugars', '0.0 g'),
                  _buildDivider(),
                  _buildNutrientRow('Sodium', '120 mg'),
                  _buildDivider(),
                  _buildNutrientRow('Potassium', '350 mg'),
                  _buildDivider(),
                  _buildNutrientRow('Vitamin D', '0 mcg'),
                  _buildDivider(),
                  _buildNutrientRow('Iron', '1.5 mg'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildCircularMacro(String label, String amount, double percent, Color color) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 40.0,
          lineWidth: 8.0,
          animation: true,
          percent: percent,
          center: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: color,
          backgroundColor: AppTheme.surface,
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildNutrientRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Text(amount, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: AppTheme.textSecondary.withOpacity(0.1));
  }
}