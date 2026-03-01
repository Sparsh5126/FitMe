import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SmartFoodCard extends StatelessWidget {
  final String id; 
  final String foodName;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  // NEW: The quantity variables
  final double consumedAmount;
  final String consumedUnit;
  final VoidCallback onDetailsTap; 
  final VoidCallback onEditDoubleTap; 
  final VoidCallback onDeleteSwipe; 

  const SmartFoodCard({
    super.key,
    required this.id,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.consumedAmount,
    required this.consumedUnit,
    required this.onDetailsTap,
    required this.onEditDoubleTap,
    required this.onDeleteSwipe,
  });

  @override
  Widget build(BuildContext context) {
    // Formats the number nicely (e.g., "1 serving" or "150.5 g")
    String displayAmount = consumedAmount.truncateToDouble() == consumedAmount 
        ? consumedAmount.toInt().toString() 
        : consumedAmount.toStringAsFixed(1);

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart, 
      onDismissed: (direction) => onDeleteSwipe(),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: GestureDetector(
        onTap: onDetailsTap,
        onDoubleTap: onEditDoubleTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(foodName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        // NEW: Displays the logged quantity
                        Text('$displayAmount $consumedUnit', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Text('$calories kcal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMacroBadge('${protein}g Pro', Colors.blueAccent),
                  _buildMacroBadge('${carbs}g Carb', Colors.orangeAccent),
                  _buildMacroBadge('${fats}g Fat', Colors.purpleAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}