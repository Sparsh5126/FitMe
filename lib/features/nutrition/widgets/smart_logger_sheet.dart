import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../services/food_api_service.dart';
import '../screens/quantity_selection_screen.dart';

class SmartLoggerSheet extends ConsumerStatefulWidget {
  const SmartLoggerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SmartLoggerSheet(),
    );
  }

  @override
  ConsumerState<SmartLoggerSheet> createState() => _SmartLoggerSheetState();
}

class _SmartLoggerSheetState extends ConsumerState<SmartLoggerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FoodApiService _apiService = FoodApiService();
  
  Timer? _debounce;
  List<FoodItem> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // The Debouncer: Waits 500ms after the user stops typing to hit the API
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _apiService.searchFood(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Make the sheet take up 85% of the screen so we have room for search results
    final height = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Small drag handle at the top
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          
          const Text("Log Food", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // The Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for any food...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _isLoading 
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // The Live Results List
          Expanded(
            child: _searchResults.isEmpty && !_isLoading
                ? const Center(
                    child: Text(
                      "Type a food name to search the global database.",
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final food = _searchResults[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "${food.calories} kcal • ${food.protein}g Pro • ${food.carbs}g Carb • ${food.fats}g Fat",
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        trailing: const Icon(Icons.add_circle_outline, color: AppTheme.accent),
                        onTap: () {
                          // When tapped, go to the Quantity Screen so they can adjust the serving size!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuantitySelectionScreen(baseFood: food),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}