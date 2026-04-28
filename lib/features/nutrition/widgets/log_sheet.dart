import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../services/food_search_service.dart';
import '../screens/quantity_selection_screen.dart';
import '../screens/favorites_screen.dart';
import 'barcode_scanner_screen.dart';
import 'custom_meal_form.dart';

class LogSheet extends ConsumerStatefulWidget {
  const LogSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LogSheet(),
    );
  }

  @override
  ConsumerState<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends ConsumerState<LogSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<FoodItem> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() => _activeTab = _tabController.index));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Set<String> _favNames(List<FoodItem> favs) =>
      favs.map((f) => f.name.toLowerCase()).toSet();

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final recents     = ref.read(recentsProvider).value ?? [];
      final favorites   = ref.read(favoritesProvider).value ?? [];
      final customs     = ref.read(customMealsProvider).value ?? [];
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
          _isSearching   = false;
          _hasSearched   = true;
        });
      }
    });
  }

  void _onFoodTapped(FoodItem food) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => QuantitySelectionScreen(baseFood: food)));
  }

  void _toggleFav(FoodItem food) {
    HapticFeedback.lightImpact();
    ref.read(foodActionsProvider).toggleFavorite(food);
  }

  Future<void> _openBarcodeScanner() async {
    HapticFeedback.lightImpact();
    final food = await BarcodeScannerScreen.scan(context);
    if (!mounted) return;
    if (food != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => QuantitySelectionScreen(baseFood: food)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height        = MediaQuery.of(context).size.height * 0.92;
    final recentFoods   = ref.watch(recentsProvider).value ?? [];
    final favs          = ref.watch(favoritesProvider).value ?? [];
    final customFoods   = ref.watch(customMealsProvider).value ?? [];
    final favNamesSet   = _favNames(favs);
    final isSearchActive = _searchController.text.isNotEmpty;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.surface,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // ── Search bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search food…',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTheme.textSecondary),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
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
              filled: true, fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Favourites shortcut row ───────────────────────────────────────
        if (!isSearchActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => FavoritesScreen.push(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.favorite_rounded,
                      color: AppTheme.accent, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    favs.isEmpty
                        ? 'No favourites yet — tap ♡ on any food'
                        : '${favs.length} favourite${favs.length == 1 ? '' : 's'} saved',
                    style: const TextStyle(
                        color: AppTheme.accent, fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.accent, size: 18),
                ]),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // ── Tabs ─────────────────────────────────────────────────────────
        if (!isSearchActive)
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.accent,
            indicatorWeight: 2,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [Tab(text: 'Recents'), Tab(text: 'Customs')],
          ),

        Expanded(
          child: isSearchActive
              ? _SearchResults(
                  results: _searchResults,
                  isLoading: _isSearching,
                  hasSearched: _hasSearched,
                  favNames: favNamesSet,
                  onTap: _onFoodTapped,
                  onFavToggle: _toggleFav,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _RecentsTab(
                      foods: recentFoods,
                      favNames: favNamesSet,
                      onTap: _onFoodTapped,
                      onFavToggle: _toggleFav,
                      onCopyYesterday: () {
                        ref.read(foodActionsProvider).copyYesterdayMeals();
                        Navigator.pop(context);
                      },
                    ),
                    _CustomsTab(
                      customFoods: customFoods,
                      favNames: favNamesSet,
                      onTap: _onFoodTapped,
                      onFavToggle: _toggleFav,
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SEARCH RESULTS
// ─────────────────────────────────────────────
class _SearchResults extends StatelessWidget {
  final List<FoodItem> results;
  final bool isLoading, hasSearched;
  final Set<String> favNames;
  final ValueChanged<FoodItem> onTap;
  final ValueChanged<FoodItem> onFavToggle;

  const _SearchResults({
    required this.results, required this.isLoading, required this.hasSearched,
    required this.favNames, required this.onTap, required this.onFavToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (hasSearched && results.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Nothing found.', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Try Smart Logger for home-cooked meals.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: results.length,
      itemBuilder: (_, i) => _FoodResultTile(
        food: results[i],
        isFavorite: favNames.contains(results[i].name.toLowerCase()),
        onTap: () => onTap(results[i]),
        onFavToggle: () => onFavToggle(results[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RECENTS TAB
// ─────────────────────────────────────────────
class _RecentsTab extends StatelessWidget {
  final List<FoodItem> foods;
  final Set<String> favNames;
  final ValueChanged<FoodItem> onTap;
  final ValueChanged<FoodItem> onFavToggle;
  final VoidCallback onCopyYesterday;

  const _RecentsTab({
    required this.foods, required this.favNames, required this.onTap,
    required this.onFavToggle, required this.onCopyYesterday,
  });

  @override
  Widget build(BuildContext context) {
    final pinned = foods.where((f) => favNames.contains(f.name.toLowerCase())).toList();
    final rest   = foods.where((f) => !favNames.contains(f.name.toLowerCase())).toList();

    return Stack(children: [
      foods.isEmpty
          ? const Center(child: Text('No recent foods yet.',
              style: TextStyle(color: AppTheme.textSecondary)))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                if (pinned.isNotEmpty) ...[
                  _ListHeader('★  Favourites'),
                  ...pinned.map((f) => _FoodResultTile(
                    food: f, isFavorite: true,
                    onTap: () => onTap(f),
                    onFavToggle: () => onFavToggle(f),
                  )),
                  if (rest.isNotEmpty) _ListHeader('Recent'),
                ],
                ...rest.map((f) => _FoodResultTile(
                  food: f,
                  isFavorite: favNames.contains(f.name.toLowerCase()),
                  onTap: () => onTap(f),
                  onFavToggle: () => onFavToggle(f),
                )),
              ],
            ),
      Positioned(
        bottom: 16, left: 60, right: 60,
        child: ElevatedButton.icon(
          onPressed: onCopyYesterday,
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text("Copy Yesterday's Meals"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surface,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// CUSTOMS TAB
// ─────────────────────────────────────────────
class _CustomsTab extends StatelessWidget {
  final List<FoodItem> customFoods;
  final Set<String> favNames;
  final ValueChanged<FoodItem> onTap;
  final ValueChanged<FoodItem> onFavToggle;

  const _CustomsTab({
    required this.customFoods, required this.favNames,
    required this.onTap, required this.onFavToggle,
  });

  @override
  Widget build(BuildContext context) {
    final pinned = customFoods
        .where((f) => favNames.contains(f.name.toLowerCase())).toList();
    final rest = customFoods
        .where((f) => !favNames.contains(f.name.toLowerCase())).toList();

    return Stack(children: [
      customFoods.isEmpty
          ? const Center(
              child: Text('No custom meals yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary)))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                if (pinned.isNotEmpty) ...[
                  _ListHeader('★  Favourites'),
                  ...pinned.map((f) => _CustomMealTile(
                    food: f, isFavorite: true,
                    onTap: () => onTap(f),
                    onFavToggle: () => onFavToggle(f),
                    onEdit: () => CustomMealFormScreen.push(context, existing: f),
                  )),
                  if (rest.isNotEmpty) _ListHeader('All Customs'),
                ],
                ...rest.map((f) => _CustomMealTile(
                  food: f,
                  isFavorite: favNames.contains(f.name.toLowerCase()),
                  onTap: () => onTap(f),
                  onFavToggle: () => onFavToggle(f),
                  onEdit: () => CustomMealFormScreen.push(context, existing: f),
                )),
              ],
            ),
      Positioned(
        bottom: 16, left: 0, right: 0,
        child: Center(
          child: FloatingActionButton.extended(
            onPressed: () => CustomMealFormScreen.push(context),
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Meal',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// LIST SECTION HEADER
// ─────────────────────────────────────────────
class _ListHeader extends StatelessWidget {
  final String text;
  const _ListHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: Text(text, style: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    )),
  );
}

// ─────────────────────────────────────────────
// CUSTOM MEAL TILE
// ─────────────────────────────────────────────
class _CustomMealTile extends StatelessWidget {
  final FoodItem food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavToggle;
  final VoidCallback onEdit;

  const _CustomMealTile({
    required this.food, required this.isFavorite,
    required this.onTap, required this.onFavToggle, required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    title: Text(food.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    subtitle: Text(
        '${food.protein}g P  ·  ${food.carbs}g C  ·  ${food.fats}g F',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${food.calories} kcal',
          style: const TextStyle(
              color: AppTheme.accent, fontWeight: FontWeight.bold)),
      const SizedBox(width: 6),
      _HeartButton(isFavorite: isFavorite, onTap: onFavToggle),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.edit_rounded,
              size: 16, color: AppTheme.textSecondary),
        ),
      ),
    ]),
    onTap: onTap,
  );
}

// ─────────────────────────────────────────────
// FOOD RESULT TILE
// ─────────────────────────────────────────────
class _FoodResultTile extends StatelessWidget {
  final FoodItem food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavToggle;

  const _FoodResultTile({
    required this.food, required this.isFavorite,
    required this.onTap, required this.onFavToggle,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    title: Text(food.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    subtitle: Text(
        '${food.protein}g P  •  ${food.carbs}g C  •  ${food.fats}g F',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${food.calories} kcal',
          style: const TextStyle(
              color: AppTheme.accent, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      _HeartButton(isFavorite: isFavorite, onTap: onFavToggle),
    ]),
    onTap: onTap,
  );
}

// ─────────────────────────────────────────────
// HEART BUTTON (reusable)
// ─────────────────────────────────────────────
class _HeartButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const _HeartButton({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isFavorite
            ? AppTheme.accent.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 18,
        color: isFavorite ? AppTheme.accent : AppTheme.textSecondary,
      ),
    ),
  );
}