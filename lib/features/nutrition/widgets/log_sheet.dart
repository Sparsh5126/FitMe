import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../services/food_api_service.dart';
import '../providers/nutrition_provider.dart';
import '../screens/quantity_selection_screen.dart';

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

class _LogSheetState extends ConsumerState<LogSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _apiService = FoodApiService();
  Timer? _debounce;

  List<FoodItem> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // Tab: 0 = Recents, 1 = Customs
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _activeTab = _tabController.index));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; _hasSearched = false; });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // First search customs + recents locally
      // Then hit APIs if nothing found
      final results = await _apiService.searchFood(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    });
  }

  void _onFoodTapped(FoodItem food) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => QuantitySelectionScreen(baseFood: food),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    final recentFoods = ref.watch(recentFoodsProvider);
    final isSearchActive = _searchController.text.isNotEmpty;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ───────────────────────────────
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // ── Search bar ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search food...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                      ),
                    // Barcode scanner
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textSecondary),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        // TODO: Phase 3 — barcode scanner
                      },
                    ),
                  ],
                ),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Tabs (hidden when searching) ─────────
          if (!isSearchActive) ...[
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 2,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [Tab(text: 'Recents'), Tab(text: 'Customs')],
            ),
          ],

          // ── Content ──────────────────────────────
          Expanded(
            child: isSearchActive
                ? _SearchResults(
                    results: _searchResults,
                    isLoading: _isSearching,
                    hasSearched: _hasSearched,
                    onTap: _onFoodTapped,
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Recents tab
                      _RecentsTab(
                        foods: recentFoods,
                        onTap: _onFoodTapped,
                        onCopyYesterday: () {
                          ref.read(nutritionProvider.notifier).copyYesterdayMeals();
                          Navigator.pop(context);
                        },
                      ),
                      // Customs tab
                      _CustomsTab(onTap: _onFoodTapped),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SEARCH RESULTS
// ─────────────────────────────────────────────
class _SearchResults extends StatelessWidget {
  final List<FoodItem> results;
  final bool isLoading;
  final bool hasSearched;
  final ValueChanged<FoodItem> onTap;

  const _SearchResults({required this.results, required this.isLoading, required this.hasSearched, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (hasSearched && results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Nothing found.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Try Smart Logger for home-cooked meals.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: results.length,
      itemBuilder: (_, i) => _FoodResultTile(food: results[i], onTap: () => onTap(results[i])),
    );
  }
}

// ─────────────────────────────────────────────
// RECENTS TAB
// ─────────────────────────────────────────────
class _RecentsTab extends StatelessWidget {
  final List<FoodItem> foods;
  final ValueChanged<FoodItem> onTap;
  final VoidCallback onCopyYesterday;

  const _RecentsTab({required this.foods, required this.onTap, required this.onCopyYesterday});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        foods.isEmpty
            ? const Center(child: Text('No recent foods yet.', style: TextStyle(color: AppTheme.textSecondary)))
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: foods.length,
                itemBuilder: (_, i) => _FoodResultTile(food: foods[i], onTap: () => onTap(foods[i])),
              ),
        // Copy yesterday's meals button
        Positioned(
          bottom: 16,
          left: 60,
          right: 60,
          child: ElevatedButton.icon(
            onPressed: onCopyYesterday,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text("Copy Yesterday's Meals"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOMS TAB
// ─────────────────────────────────────────────
class _CustomsTab extends ConsumerWidget {
  final ValueChanged<FoodItem> onTap;
  const _CustomsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customFoods = ref.watch(customFoodsProvider);

    return Stack(
      children: [
        customFoods.isEmpty
            ? const Center(child: Text('No custom foods yet.\nTap + to add one.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)))
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: customFoods.length,
                itemBuilder: (_, i) => _FoodResultTile(food: customFoods[i], onTap: () => onTap(customFoods[i])),
              ),
        // Add custom food button
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton(
              onPressed: () {
                // TODO: Open custom food creation form
              },
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FOOD RESULT TILE
// ─────────────────────────────────────────────
class _FoodResultTile extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;

  const _FoodResultTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(
        '${food.protein}g P  •  ${food.carbs}g C  •  ${food.fats}g F',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Text('${food.calories} kcal', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }
}