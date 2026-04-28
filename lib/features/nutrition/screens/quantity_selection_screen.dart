import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/oil_level_selector.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../providers/oil_level_provider.dart';

class QuantitySelectionScreen extends ConsumerStatefulWidget {
  final FoodItem baseFood;
  final String? editItemId;
  final bool popToHome;

  const QuantitySelectionScreen({
    super.key,
    required this.baseFood,
    this.editItemId,
    this.popToHome = true,
  });

  @override
  ConsumerState<QuantitySelectionScreen> createState() =>
      _QuantitySelectionScreenState();
}

class _QuantitySelectionScreenState
    extends ConsumerState<QuantitySelectionScreen> {
  late TextEditingController _amountController;
  late String _selectedUnit;
  late FoodItem _scaled;
  bool _logging = false;
  OilLevel _oilLevel = OilLevel.normal;
  bool _isOily = false;

  static const _units = [
    'g', 'kg', 'ml', 'l', 'piece', 'serving', 'cup', 'tbsp', 'tsp',
    'slice', 'katori', 'plate', 'scoop', 'bar'
  ];

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.baseFood.consumedUnit;
    _amountController = TextEditingController(
      text: widget.baseFood.consumedAmount % 1 == 0
          ? widget.baseFood.consumedAmount.toInt().toString()
          : widget.baseFood.consumedAmount.toString(),
    );
    _scaled = widget.baseFood;
    _amountController.addListener(_onAmountChanged);
    _isOily = isOilyIndianFood(widget.baseFood.name);
    if (_isOily) {
      // Load persisted preference after first frame so ref is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final saved = ref.read(oilPreferenceProvider);
        final level = saved[widget.baseFood.name.toLowerCase()] ?? OilLevel.normal;
        if (level != _oilLevel) {
          setState(() {
            _oilLevel = level;
            _scaled = applyOilLevel(widget.baseFood, _oilLevel);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final val = double.tryParse(_amountController.text);
    if (val != null && val > 0) {
      final equivalent = _getEquivalentBaseAmount(val, _selectedUnit);
      final base = widget.baseFood.scaleToAmount(equivalent);
      setState(() => _scaled = applyOilLevel(base, _oilLevel));
    }
  }

  void _onOilLevelChanged(OilLevel level) {
    setState(() {
      _oilLevel = level;
      final val = double.tryParse(_amountController.text) ?? widget.baseFood.consumedAmount;
      final equivalent = _getEquivalentBaseAmount(val, _selectedUnit);
      final base = widget.baseFood.scaleToAmount(equivalent);
      _scaled = applyOilLevel(base, level);
    });
    ref.read(oilPreferenceProvider.notifier).set(widget.baseFood.name, level);
  }

  double _getEquivalentBaseAmount(double inputAmount, String inputUnit) {
    if (inputUnit == widget.baseFood.consumedUnit) return inputAmount;
    final baseUnit = widget.baseFood.consumedUnit;
    bool isW(String u) => ['g', 'kg', 'ml', 'l'].contains(u);
    if (isW(baseUnit) && isW(inputUnit)) {
      if ((inputUnit == 'kg' || inputUnit == 'l') &&
          (baseUnit == 'g' || baseUnit == 'ml')) return inputAmount * 1000;
      if ((inputUnit == 'g' || inputUnit == 'ml') &&
          (baseUnit == 'kg' || baseUnit == 'l')) return inputAmount / 1000;
      return inputAmount;
    }
    if (isW(baseUnit) && !isW(inputUnit)) {
      return inputAmount * widget.baseFood.consumedAmount;
    }
    if (!isW(baseUnit) && isW(inputUnit)) {
      double grams = inputAmount;
      if (inputUnit == 'kg' || inputUnit == 'l') grams *= 1000;
      return grams / 100.0;
    }
    return inputAmount;
  }

  void _changeUnit(String newUnit) {
    if (newUnit == _selectedUnit) return;
    final oldUnit = _selectedUnit;
    final currentVal =
        double.tryParse(_amountController.text) ?? widget.baseFood.consumedAmount;
    double newVal = currentVal;
    bool isW(String u) => ['g', 'kg', 'ml', 'l'].contains(u);
    if (isW(oldUnit) && isW(newUnit)) {
      if ((oldUnit == 'g' || oldUnit == 'ml') &&
          (newUnit == 'kg' || newUnit == 'l')) newVal = currentVal / 1000;
      if ((oldUnit == 'kg' || oldUnit == 'l') &&
          (newUnit == 'g' || newUnit == 'ml')) newVal = currentVal * 1000;
    } else if (isW(oldUnit) && !isW(newUnit)) {
      final weightPerServing = isW(widget.baseFood.consumedUnit)
          ? widget.baseFood.consumedAmount
          : 100.0;
      double grams = currentVal;
      if (oldUnit == 'kg' || oldUnit == 'l') grams *= 1000;
      newVal = grams / weightPerServing;
    } else if (!isW(oldUnit) && isW(newUnit)) {
      final weightPerServing = isW(widget.baseFood.consumedUnit)
          ? widget.baseFood.consumedAmount
          : 100.0;
      newVal = currentVal * weightPerServing;
      if (newUnit == 'kg' || newUnit == 'l') newVal /= 1000;
    }
    setState(() => _selectedUnit = newUnit);
    final display =
        newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toStringAsFixed(1);
    _amountController.removeListener(_onAmountChanged);
    _amountController.text = display;
    _amountController.selection =
        TextSelection.fromPosition(TextPosition(offset: display.length));
    _amountController.addListener(_onAmountChanged);
    _onAmountChanged();
  }

  void _adjustAmount(double delta) {
    final current = double.tryParse(_amountController.text) ??
        widget.baseFood.consumedAmount;
    final newVal = (current + delta).clamp(0.1, 9999.0);
    final display =
        newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toStringAsFixed(1);
    _amountController.text = display;
    _amountController.selection =
        TextSelection.fromPosition(TextPosition(offset: display.length));
  }

  Future<void> _logFood() async {
    setState(() => _logging = true);
    HapticFeedback.mediumImpact();
    final isEdit = widget.editItemId != null;
    final food = _scaled.copyWith(
      id: isEdit
          ? widget.editItemId
          : '${widget.baseFood.id}_${DateTime.now().millisecondsSinceEpoch}',
      consumedUnit: _selectedUnit,
      dateString: FoodItem.dateFor(ref.read(selectedDateProvider)),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    if (isEdit) {
      await ref.read(foodActionsProvider).updateFood(food);
    } else {
      await ref.read(foodActionsProvider).logFood(food);
    }
    if (mounted) {
      if (widget.popToHome) {
        Navigator.of(context)
            .popUntil((route) => route.isFirst || route.settings.name == '/home');
      } else {
        Navigator.pop(context, true);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${food.name} ${isEdit ? 'updated' : 'logged'}! ✓'),
        backgroundColor: AppTheme.accent.withOpacity(0.9),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Issue 3: build serving-size hint string ──────────────────────────
  String? _servingHint() {
    final food = widget.baseFood;
    // Only show for non-weight base units (i.e. custom / recipe-style meals)
    final bool isWeightBased =
        ['g', 'kg', 'ml', 'l'].contains(food.consumedUnit);
    if (isWeightBased) return null;

    final parts = <String>[];

    // Per-serving weight if the food carries it (custom meals often do via
    // servingWeightGrams field; fall back gracefully)
    final double? servingGrams = food.servingWeightGrams;
    if (servingGrams != null && servingGrams > 0) {
      final g = servingGrams % 1 == 0
          ? servingGrams.toInt().toString()
          : servingGrams.toStringAsFixed(0);
      parts.add('1 ${food.consumedUnit} = ${g}g');
    }

    // Recipe metadata: total servings
    final int? totalServings = food.totalServings;
    if (totalServings != null && totalServings > 1) {
      parts.add('Recipe makes $totalServings servings');
    }

    // Serving description (e.g. "1 bowl", "2 rotis", "full recipe")
    final String? desc = food.servingDescription;
    if (desc != null && desc.isNotEmpty) {
      parts.add(desc);
    }

    if (parts.isEmpty) return null;
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final hint = _servingHint();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(widget.baseFood.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quantity input ───────────────────────────────
                    const Text('Quantity',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        _AdjustBtn(
                            icon: Icons.remove_rounded,
                            onTap: () => _adjustAmount(-1)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'))
                            ],
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppTheme.accent, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _AdjustBtn(
                            icon: Icons.add_rounded,
                            onTap: () => _adjustAmount(1)),
                      ],
                    ),

                    // ── Issue 3: Serving size hint ───────────────────
                    if (hint != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.accent.withOpacity(0.2)),
                        ),
                        child: Text(
                          hint,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Unit selector ────────────────────────────────
                    const Text('Unit',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _units.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final unit = _units[i];
                          final isSelected = unit == _selectedUnit;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _changeUnit(unit);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accent.withOpacity(0.15)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSelected
                                        ? AppTheme.accent
                                        : Colors.transparent,
                                    width: 1.5),
                              ),
                              child: Text(unit,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  )),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Oil/Richness Slider (oily Indian foods only) ─
                    if (_isOily) ...[
                      const SizedBox(height: 20),
                      OilLevelSelector(
                        value: _oilLevel,
                        onChanged: _onOilLevelChanged,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Live macro preview ───────────────────────────
                    const Text('Nutritional Values',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text('${_scaled.calories}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900)),
                          const Text('kcal',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _MacroCell(
                                  label: 'Protein',
                                  value: '${_scaled.protein}g',
                                  color: Colors.blueAccent),
                              _Divider(),
                              _MacroCell(
                                  label: 'Carbs',
                                  value: '${_scaled.carbs}g',
                                  color: Colors.orangeAccent),
                              _Divider(),
                              _MacroCell(
                                  label: 'Fats',
                                  value: '${_scaled.fats}g',
                                  color: Colors.purpleAccent),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (widget.baseFood.isAiLogged)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amberAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Text('🪄', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'AI-estimated values. Macros may vary.',
                                  style: TextStyle(
                                      color: Colors.amberAccent, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Log button ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _logging ? null : _logFood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _logging
                      ? const CircularProgressIndicator(
                          color: AppTheme.background, strokeWidth: 2)
                      : const Text('Log Food',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AdjustBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: AppTheme.accent),
      ),
    );
  }
}

class _MacroCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 36, color: Colors.white.withOpacity(0.08));
  }
}