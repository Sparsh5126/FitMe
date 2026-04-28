import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../models/custom_meal_ingredient.dart';
import '../providers/nutrition_provider.dart';
import '../services/custom_meal_service.dart';
import '../services/food_search_service.dart';
import 'barcode_scanner_screen.dart';

class CustomMealFormScreen extends ConsumerStatefulWidget {
  final FoodItem? existing;
  const CustomMealFormScreen({super.key, this.existing});

  static Future<void> push(BuildContext context, {FoodItem? existing}) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomMealFormScreen(existing: existing),
          fullscreenDialog: true,
        ),
      );

  @override
  ConsumerState<CustomMealFormScreen> createState() =>
      _CustomMealFormScreenState();
}

class _CustomMealFormScreenState extends ConsumerState<CustomMealFormScreen> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController(text: '1');

  List<CustomMealIngredient> _ingredients = [];
  List<FoodItem> _searchResults = [];
  bool _isSearching = false;
  bool _searchActive = false;
  bool _saving = false;
  Timer? _debounce;

  bool get _isEdit => widget.existing != null;

  int get _totalCal => _ingredients.fold(0, (s, i) => s + i.calories);
  int get _totalPro => _ingredients.fold(0, (s, i) => s + i.protein);
  int get _totalCarb => _ingredients.fold(0, (s, i) => s + i.carbs);
  int get _totalFat => _ingredients.fold(0, (s, i) => s + i.fats);
  int get _servings => int.tryParse(_servingsCtrl.text) ?? 1;
  int get _calPerServing =>
      _servings > 0 ? (_totalCal / _servings).round() : _totalCal;
  int get _proPerServing =>
      _servings > 0 ? (_totalPro / _servings).round() : _totalPro;
  int get _carbPerServing =>
      _servings > 0 ? (_totalCarb / _servings).round() : _totalCarb;
  int get _fatPerServing =>
      _servings > 0 ? (_totalFat / _servings).round() : _totalFat;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _loadIngredients();
    }
    _servingsCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadIngredients() async {
    final items =
        await CustomMealService.fetchIngredients(widget.existing!.id);
    if (mounted) setState(() => _ingredients = items);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    _servingsCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchActive = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchActive = true;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final recents = ref.read(recentsProvider).value ?? [];
      final favorites = ref.read(favoritesProvider).value ?? [];
      final customs = ref.read(customMealsProvider).value ?? [];
      final commonFoods = ref.read(commonFoodsProvider).value ?? [];
      final result = await FoodSearchService.logSheetSearch(
        query: query,
        favorites: favorites,
        recents: recents,
        customMeals: customs,
        commonFoods: commonFoods,
      );
      if (mounted) {
        setState(() {
          _searchResults = result.foods;
          _isSearching = false;
        });
      }
    });
  }

  void _addFromSearch(FoodItem food) {
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _searchActive = false;
    });
    _showQuantityPicker(food);
  }

  Future<void> _openBarcodeScanner() async {
    HapticFeedback.lightImpact();
    final food = await BarcodeScannerScreen.scan(context);
    if (!mounted || food == null) return;
    // Scanner already did the lookup — pass food directly to quantity picker.
    _showQuantityPicker(food);
  }


  void _showQuantityPicker(FoodItem food, {int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuantityPickerSheet(
        food: food,
        existing: editIndex != null ? _ingredients[editIndex] : null,
        onConfirm: (ingredient) {
          setState(() {
            if (editIndex != null) {
              _ingredients[editIndex] = ingredient;
            } else {
              _ingredients.add(ingredient);
            }
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Please enter a meal name');
      return;
    }
    if (_ingredients.isEmpty) {
      _snack('Add at least one ingredient');
      return;
    }
    setState(() => _saving = true);
    final draft = CustomMealDraft(
      name: _nameCtrl.text.trim(),
      servings: _servings,
      ingredients: _ingredients,
      notes: _notesCtrl.text.trim(),
    );
    try {
      if (_isEdit) {
        await CustomMealService.update(widget.existing!.id, draft);
      } else {
        await CustomMealService.create(draft);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete meal?',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Permanently delete "${_nameCtrl.text}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await CustomMealService.delete(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Meal' : 'New Custom Meal',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isEdit)
            IconButton(
              icon:
                  const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent))
                : const Text('Save',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // ── Meal name ──────────────────────────────────────────────
            _Label('Meal Name'),
            _textField(_nameCtrl, 'e.g. Mum\'s Dal Tadka'),
            const SizedBox(height: 24),

            // ── Macro summary card ──────────────────────────────────────
            if (_ingredients.isNotEmpty) ...[
              _MacroCard(
                totalCal: _totalCal,
                calPerServing: _calPerServing,
                proPerServing: _proPerServing,
                carbPerServing: _carbPerServing,
                fatPerServing: _fatPerServing,
                servings: _servings,
              ),
              const SizedBox(height: 20),
            ],

            // ── Servings ───────────────────────────────────────────────
            _Label('Recipe makes (servings)'),
            Row(children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _servingsCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec('1'),
                ),
              ),
              const SizedBox(width: 12),
              const Text('serving(s)',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 24),

            // ── Ingredient search ──────────────────────────────────────
            _Label('Ingredients'),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Search to add ingredient…').copyWith(
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textSecondary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accent)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppTheme.textSecondary),
                      onPressed: _openBarcodeScanner,
                      tooltip: 'Scan barcode',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Search result dropdown
            if (_searchActive && _searchResults.isNotEmpty)
              _SearchDropdown(
                  results: _searchResults, onTap: _addFromSearch),

            if (_searchActive && !_isSearching && _searchResults.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('No results found',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),

            const SizedBox(height: 12),

            // ── Ingredient list ────────────────────────────────────────
            if (_ingredients.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.surface.withOpacity(0.8)),
                ),
                child: const Center(
                  child: Text('Search above to add ingredients',
                      style:
                          TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              Column(
                children: _ingredients.asMap().entries.map((e) {
                  final idx = e.key;
                  final ing = e.value;
                  return _IngredientTile(
                    ingredient: ing,
                    onEdit: () {
                      final food = FoodItem(
                        id: ing.foodId,
                        name: ing.name,
                        calories: ing.baseCal,
                        protein: ing.basePro,
                        carbs: ing.baseCarb,
                        fats: ing.baseFat,
                        consumedAmount: ing.baseAmount,
                        consumedUnit: ing.unit,
                      );
                      _showQuantityPicker(food, editIndex: idx);
                    },
                    onRemove: () =>
                        setState(() => _ingredients.removeAt(idx)),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),

            // ── Notes ──────────────────────────────────────────────────
            _Label('Notes (optional)'),
            _textField(_notesCtrl, 'Cooking tips, source, etc.',
                maxLines: 3),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _textField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: _dec(hint),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Macro summary card
// ─────────────────────────────────────────────────────────────────────────────
class _MacroCard extends StatelessWidget {
  final int totalCal, calPerServing, proPerServing, carbPerServing,
      fatPerServing, servings;
  const _MacroCard({
    required this.totalCal,
    required this.calPerServing,
    required this.proPerServing,
    required this.carbPerServing,
    required this.fatPerServing,
    required this.servings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nutrition per serving',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              Text('Total: $totalCal kcal',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroChip('$calPerServing', 'kcal', AppTheme.accent),
              _MacroChip('${proPerServing}g', 'Protein', Colors.blueAccent),
              _MacroChip('${carbPerServing}g', 'Carbs', Colors.orangeAccent),
              _MacroChip('${fatPerServing}g', 'Fats', Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MacroChip(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Search dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _SearchDropdown extends StatelessWidget {
  final List<FoodItem> results;
  final ValueChanged<FoodItem> onTap;
  const _SearchDropdown({required this.results, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: results.take(6).map((food) {
          return ListTile(
            dense: true,
            title: Text(food.name,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(
                '${food.calories} kcal · '
                '${food.consumedAmount.toStringAsFixed(0)} ${food.consumedUnit}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.add_circle_outline_rounded,
                color: AppTheme.accent, size: 20),
            onTap: () => onTap(food),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ingredient tile
// ─────────────────────────────────────────────────────────────────────────────
class _IngredientTile extends StatelessWidget {
  final CustomMealIngredient ingredient;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _IngredientTile(
      {required this.ingredient,
      required this.onEdit,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(ingredient.name,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(
            '${ingredient.amount.toStringAsFixed(ingredient.amount == ingredient.amount.roundToDouble() ? 0 : 1)} '
            '${ingredient.unit}  ·  ${ingredient.calories} kcal',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onEdit,
              child: const Icon(Icons.edit_rounded,
                  size: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _QuantityPickerSheet extends StatefulWidget {
  final FoodItem food;
  final CustomMealIngredient? existing;
  final void Function(CustomMealIngredient) onConfirm;
  const _QuantityPickerSheet(
      {required this.food, this.existing, required this.onConfirm});

  @override
  State<_QuantityPickerSheet> createState() => _QuantityPickerSheetState();
}

class _QuantityPickerSheetState extends State<_QuantityPickerSheet> {
  late TextEditingController _amountCtrl;
  late double _amount;

  double get _base => widget.food.consumedAmount;
  String get _unit => widget.food.consumedUnit;

  int get _cal =>
      (widget.food.calories * _amount / _base).round();
  int get _pro =>
      (widget.food.protein * _amount / _base).round();
  int get _carb =>
      (widget.food.carbs * _amount / _base).round();
  int get _fat =>
      (widget.food.fats * _amount / _base).round();

  @override
  void initState() {
    super.initState();
    _amount = widget.existing?.amount ?? _base;
    _amountCtrl =
        TextEditingController(text: _amount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String _getServingInfo() {
    final food = widget.food;
    if (food.servingDescription != null && food.servingDescription!.isNotEmpty) {
      return food.servingDescription!;
    }
    if (food.servingWeightGrams != null && food.servingWeightGrams! > 0) {
      final g = food.servingWeightGrams! % 1 == 0 
        ? food.servingWeightGrams!.toInt().toString() 
        : food.servingWeightGrams!.toStringAsFixed(0);
      return '1 serving = ${g}g';
    }
    
    final amt = food.consumedAmount % 1 == 0 
      ? food.consumedAmount.toInt().toString() 
      : food.consumedAmount.toString();
      
    if (food.consumedUnit != 'serving') {
      return '1 serving = $amt ${food.consumedUnit}';
    }
    return '1 serving';
  }

  void _adjust(double delta) {
    setState(() {
      _amount = (_amount + delta).clamp(1, 9999).toDouble();
      _amountCtrl.text = _amount.toStringAsFixed(0);
    });
  }

  void _onTyped(String v) {
    final parsed = double.tryParse(v);
    if (parsed != null && parsed > 0) {
      setState(() => _amount = parsed);
    }
  }

  void _confirm() {
    final ing = CustomMealIngredient(
      foodId: widget.food.id,
      name: widget.food.name,
      amount: _amount,
      unit: _unit,
      calories: _cal,
      protein: _pro,
      carbs: _carb,
      fats: _fat,
      baseAmount: _base,
      baseCal: widget.food.calories,
      basePro: widget.food.protein,
      baseCarb: widget.food.carbs,
      baseFat: widget.food.fats,
    );
    widget.onConfirm(ing);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.food.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            _getServingInfo(),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
              'Base: ${_base.toStringAsFixed(0)} $_unit = '
              '${widget.food.calories} kcal',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          // Amount row
          Row(
            children: [
              _CircleBtn(Icons.remove_rounded, () => _adjust(-_step)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  onChanged: _onTyped,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                    ),
                    suffixText: _unit,
                    suffixStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CircleBtn(Icons.add_rounded, () => _adjust(_step)),
            ],
          ),

          const SizedBox(height: 16),

          // Macro preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniMacro('$_cal kcal', 'Calories', AppTheme.accent),
                _MiniMacro('${_pro}g', 'Protein', Colors.blueAccent),
                _MiniMacro('${_carb}g', 'Carbs', Colors.orangeAccent),
                _MiniMacro('${_fat}g', 'Fats', Colors.purpleAccent),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Add Ingredient',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  double get _step => _base >= 100 ? 25 : (_base >= 10 ? 5 : 1);
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.accent, size: 24),
        ),
      );
}

class _MiniMacro extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MiniMacro(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      );
}