import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';

class QuantitySelectionScreen extends ConsumerStatefulWidget {
  final FoodItem baseFood; 
  final String? editItemId; 

  const QuantitySelectionScreen({super.key, required this.baseFood, this.editItemId});

  @override
  ConsumerState<QuantitySelectionScreen> createState() => _QuantitySelectionScreenState();
}

class _QuantitySelectionScreenState extends ConsumerState<QuantitySelectionScreen> {
  late TextEditingController _controller;
  double _currentAmount = 1.0;
  String _selectedUnit = 'serving';
  final List<String> _units = ['serving', 'g', 'oz', 'ml'];

  // MOCK: Assuming 1 serving of this item = 150 grams
  final double _baseGramsPerServing = 150.0; 

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.baseFood.consumedAmount;
    _selectedUnit = widget.baseFood.consumedUnit;
    
    // Format the starting number cleanly
    String initialText = _currentAmount.truncateToDouble() == _currentAmount 
        ? _currentAmount.toInt().toString() 
        : _currentAmount.toStringAsFixed(1);
        
    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Calculates the macro multiplier based on the current unit and amount
  double get _macroMultiplier {
    if (_selectedUnit == 'serving') return _currentAmount;
    if (_selectedUnit == 'g' || _selectedUnit == 'ml') return _currentAmount / _baseGramsPerServing;
    if (_selectedUnit == 'oz') return _currentAmount / (_baseGramsPerServing / 28.35); // 1 oz = 28.35g
    return 1.0;
  }

  // The bidirectional math conversion
  void _changeUnit(String newUnit) {
    if (newUnit == _selectedUnit) return;

    double baseServings = _macroMultiplier;
    double newAmount = 0.0;
    
    if (newUnit == 'serving') newAmount = baseServings;
    else if (newUnit == 'g' || newUnit == 'ml') newAmount = baseServings * _baseGramsPerServing;
    else if (newUnit == 'oz') newAmount = baseServings * (_baseGramsPerServing / 28.35);

    setState(() {
      _selectedUnit = newUnit;
      _currentAmount = newAmount;
      _controller.text = _currentAmount.truncateToDouble() == _currentAmount 
          ? _currentAmount.toInt().toString() 
          : _currentAmount.toStringAsFixed(1);
    });
  }

void _logOrUpdateFood() {
    final m = _macroMultiplier;
    final newItem = FoodItem(
      id: widget.editItemId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.baseFood.name,
      calories: (widget.baseFood.calories * m).round(),
      protein: (widget.baseFood.protein * m).round(),
      carbs: (widget.baseFood.carbs * m).round(),
      fats: (widget.baseFood.fats * m).round(),
      consumedAmount: _currentAmount, 
      consumedUnit: _selectedUnit,    
    );

    if (widget.editItemId != null) {
      ref.read(nutritionProvider.notifier).updateFood(widget.editItemId!, newItem);
    } else {
      // THE FIX: Use our new clean addFood method instead of modifying state directly!
      ref.read(nutritionProvider.notifier).addFood(newItem);
    }
    
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final m = _macroMultiplier;
    final currentCals = (widget.baseFood.calories * m).round();
    final currentPro = (widget.baseFood.protein * m).round();
    final currentCarb = (widget.baseFood.carbs * m).round();
    final currentFat = (widget.baseFood.fats * m).round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.editItemId != null ? 'Edit Quantity' : 'Adjust Quantity', style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // THE FIX: Wrap the top content in an Expanded + SingleChildScrollView
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.baseFood.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('1 serving = ${_baseGramsPerServing.toInt()}g', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      const SizedBox(height: 24),
                      
                      // DYNAMIC MACRO ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildDynamicMacro('${currentPro}g\nPro', Colors.blueAccent),
                          _buildDynamicMacro('$currentCals\nKcal', AppTheme.accent),
                          _buildDynamicMacro('${currentCarb}g\nCarb', Colors.orangeAccent),
                          _buildDynamicMacro('${currentFat}g\nFat', Colors.purpleAccent),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // THE TEXT INPUT BOX
                      Center(
                        child: IntrinsicWidth(
                          child: TextField(
                            controller: _controller,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            autofocus: true, 
                            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                            onChanged: (val) {
                              setState(() {
                                _currentAmount = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ),

                      // UNIT SELECTOR TOGGLE
                      Container(
                        margin: const EdgeInsets.only(top: 24, bottom: 20),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: _units.map((unit) {
                            final isSelected = _selectedUnit == unit;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _changeUnit(unit),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.accent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    unit,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? AppTheme.background : AppTheme.textSecondary),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // THE BUTTON: Anchored perfectly above the keyboard
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _logOrUpdateFood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(widget.editItemId != null ? 'Update Meal' : 'Log Food', style: const TextStyle(color: AppTheme.background, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicMacro(String text, Color color) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}