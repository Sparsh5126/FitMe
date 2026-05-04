import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/oil_level_selector.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../providers/oil_level_provider.dart';
import '../services/gemini_service.dart';
import '../services/food_search_service.dart';
import '../screens/quantity_selection_screen.dart';
import '../../dashboard/providers/user_provider.dart';

import '../models/custom_meal_ingredient.dart';
import '../services/custom_meal_service.dart';
import 'custom_meal_form.dart';

class SmartLoggerSheet extends ConsumerStatefulWidget {
  const SmartLoggerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmartLoggerSheet(),
    );
  }

  @override
  ConsumerState<SmartLoggerSheet> createState() => _SmartLoggerSheetState();
}

class _SmartLoggerSheetState extends ConsumerState<SmartLoggerSheet> {
  final _inputController    = TextEditingController();
  final _searchController   = TextEditingController();
  final _scrollController   = ScrollController();
  final List<_ChatMessage>  _messages = [];

  bool _isLoading      = false;
  bool _isListening    = false;
  bool _isSearching    = false;

  List<FoodItem> _searchResults = [];
  bool _hasSearched = false;
  Timer? _searchDebounce;

  final _speech = stt.SpeechToText();
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadHistory();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('[Speech] error: $e'),
    );
  }

  Future<void> _loadHistory() async {
    final today = FoodItem.dateFor(DateTime.now());
    final history = await _SmartLoggerHistory.loadMessages(today);
    if (mounted) {
      setState(() {
        _messages.addAll(history);
      });
      _scrollToBottom();
    }
  }

  void _saveHistory() {
    final today = FoodItem.dateFor(DateTime.now());
    _SmartLoggerHistory.saveMessages(today, _messages);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _speech.cancel();
    super.dispose();
  }

  int get _logsUsed {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return 0;
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (profile.smartLoggerLastResetDate != today) return 0;
    return profile.smartLoggerUsedToday;
  }

  bool get _limitReached => _logsUsed >= 10;

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading || _limitReached) return;

    HapticFeedback.lightImpact();
    _inputController.clear();
    setState(() { _messages.add(_ChatMessage.user(text)); _isLoading = true; });
    _saveHistory();
    _scrollToBottom();

    final commonFoods = ref.read(commonFoodsProvider).value ?? [];
    final recents     = ref.read(recentsProvider).value ?? [];
    final customs     = ref.read(customMealsProvider).value ?? [];

    final lowerText = text.toLowerCase();

    if (lowerText.startsWith('/aionly ')) {
      final aiQuery = text.substring(8).trim();
      if (aiQuery.isEmpty) {
        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage.error("Please provide a food description after /aionly."));
        });
        _saveHistory();
        _scrollToBottom();
        return;
      }
      await _runGemini(() => GeminiService.parseFoodSafe(aiQuery));
      return;
    }

    if (lowerText.startsWith('/custommeal ')) {
      final parsedMeal = FoodSearchService.parseCustomMealCommand(
          text: text, recents: recents, customMeals: customs, commonFoods: commonFoods);
      
      setState(() => _isLoading = false);

      if (parsedMeal != null) {
        final draftIngs = parsedMeal.ingredients.map((m) => CustomMealIngredient(
          foodId: m.food.id,
          name: m.food.name,
          amount: m.food.consumedAmount,
          unit: m.food.consumedUnit,
          calories: m.food.calories,
          protein: m.food.protein,
          carbs: m.food.carbs,
          fats: m.food.fats,
          baseAmount: m.food.consumedAmount,
          baseCal: m.food.calories,
          basePro: m.food.protein,
          baseCarb: m.food.carbs,
          baseFat: m.food.fats,
        )).toList();

        setState(() {
          _messages.add(_ChatMessage.foodCard(
            parsedMeal.summary, 
            noAiUsed: true, 
            isCustomMealDraft: true, 
            draftIngredients: draftIngs,
          ));
        });
      } else {
        setState(() {
          _messages.add(_ChatMessage.error("Could not parse custom meal. Ensure format: /custommeal \"Name\" ingredients..."));
        });
      }
      _saveHistory();
      _scrollToBottom();
      return;
    }

    final parsed = FoodSearchService.parseNaturalMeal(
      text: text,
      recents: recents,
      customMeals: customs,
      commonFoods: commonFoods,
    );
    if (parsed.isNotEmpty) {
      setState(() {
        _isLoading = false;
        for (final item in parsed) {
          _messages.add(_ChatMessage.foodCard(item.food, noAiUsed: true));
        }
      });
      _saveHistory();
      _scrollToBottom();
      return;
    }

    await _runGemini(() => GeminiService.parseFoodSafe(text));
  }

  Future<void> _pickPhoto() async {
    if (_isLoading || _limitReached) return;
    HapticFeedback.lightImpact();

    final picker = ImagePicker();
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;

    final file = File(xfile.path);
    setState(() {
      _messages.add(_ChatMessage.user('📷 Photo submitted'));
      _isLoading = true;
    });
    _saveHistory();
    _scrollToBottom();

    await _runGemini(() => GeminiService.parseFoodFromImage(file));
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    if (_isLoading || _limitReached) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      _showSnackbar('Microphone not available on this device.', error: true);
      return;
    }

    setState(() => _isListening = true);
    HapticFeedback.mediumImpact();

    await _speech.listen(
      onResult: (result) async {
        if (result.finalResult) {
          final transcript = result.recognizedWords.trim();
          await _speech.stop();
          setState(() => _isListening = false);

          if (transcript.isEmpty) {
            _showSnackbar('Could not hear anything. Try again.', error: true);
            return;
          }

          _inputController.text = transcript;
          await Future.delayed(const Duration(milliseconds: 400));
          await _sendMessage();
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN', 
    );
  }

  Future<void> _runGemini(Future<List<FoodItem>> Function() fn) async {
    List<FoodItem> foods = [];
    try {
      foods = await fn();
    } catch (e) {
      debugPrint('[SmartLogger] error: $e');
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (foods.isEmpty) {
        _messages.add(_ChatMessage.error(
            "Couldn't identify that food. Try describing more specifically,\n"
            "e.g. '2 rotis with dal and sabzi', or search below."));
      } else {
        for (final food in foods) {
          _messages.add(_ChatMessage.foodCard(food));
        }
        ref.read(foodActionsProvider).incrementSmartLoggerCount();
      }
    });
    _saveHistory();
    _scrollToBottom();
  }

  Future<void> _onSearchChanged(String query) async {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _hasSearched = false; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final recents     = ref.read(recentsProvider).value ?? [];
      final customs     = ref.read(customMealsProvider).value ?? [];
      final commonFoods = ref.read(commonFoodsProvider).value ?? [];

      final result = await FoodSearchService.smartLoggerSearch(
        query: query,
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

  void _onSearchFoodTapped(FoodItem food) {
    _searchController.clear();
    setState(() { _searchResults = []; _hasSearched = false; });
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => QuantitySelectionScreen(baseFood: food)));
  }

  void _checkPop() {
    final pendingCount = _messages
        .where((m) => m.type == _MsgType.foodCard && m.accepted == null)
        .length;
    if (pendingCount == 0 && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _acceptFood(FoodItem food, {String? originalId}) async {
    HapticFeedback.mediumImpact();
    try {
      int msgIndex = -1;
      if (originalId != null) {
        msgIndex = _messages.indexWhere((m) => m.food?.id == originalId);
      }
      if (msgIndex == -1) {
        msgIndex = _messages.indexWhere((m) => m.food?.id == food.id);
      }
      if (msgIndex == -1) {
        msgIndex = _messages.indexWhere(
          (m) => m.type == _MsgType.foodCard &&
                 m.accepted == null &&
                 m.food?.name.toLowerCase() == food.name.toLowerCase(),
        );
      }

      if (msgIndex != -1) {
        final msg = _messages[msgIndex];
        final bool aiWasUsed = !msg.noAiUsed;
        
        if (msg.isCustomMealDraft && msg.draftIngredients != null) {
          final customs = ref.read(customMealsProvider).value ?? [];
          String finalName = food.name;
          int counter = 1;
          while (customs.any((c) => c.name.toLowerCase() == finalName.toLowerCase())) {
             finalName = '${food.name} ($counter)';
             counter++;
          }

          final toLog = food.copyWith(name: finalName, isAiLogged: aiWasUsed);
          await ref.read(foodActionsProvider).logFood(toLog);
          
          final draft = CustomMealDraft(
            name: finalName,
            servings: 1,
            ingredients: msg.draftIngredients!,
            notes: '',
          );
          await CustomMealService.create(draft);
          _showSnackbar('Meal "$finalName" Logged & Saved! ✓');
          
          if (mounted) {
            setState(() {
              _messages[msgIndex] = _messages[msgIndex].copyAccepted(true, newFood: toLog);
            });
          }
        } else {
          final toLog = food.copyWith(isAiLogged: aiWasUsed);
          await ref.read(foodActionsProvider).logFood(toLog);
          if (mounted) {
            setState(() {
              _messages[msgIndex] = _messages[msgIndex].copyAccepted(true);
            });
          }
        }
      }

      _saveHistory();
      ref.invalidate(nutritionProvider);
      ref.invalidate(dailyTotalsProvider);
      _checkPop();

    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to log ${food.name}: $e', error: true);
      }
    }
  }

  void _editFood(FoodItem food) {
    HapticFeedback.lightImpact();

    final msgIndex = _messages.indexWhere((m) => m.food?.id == food.id);
    final msg = msgIndex != -1 ? _messages[msgIndex] : null;

    if (msg != null && msg.isCustomMealDraft && msg.draftIngredients != null) {
      CustomMealFormScreen.push(
        context, 
        draftName: food.name, 
        draftIngredients: msg.draftIngredients
      ).then((wasSaved) {
        if (!mounted || wasSaved != true) return;
        setState(() {
          if (msgIndex != -1) _messages[msgIndex] = _messages[msgIndex].copyAccepted(true);
        });
        _saveHistory();
        _checkPop();
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuantitySelectionScreen(
          baseFood: food,
          popToHome: false,
        ),
      ),
    ).then((wasLogged) {
      if (!mounted || wasLogged != true) return;
      setState(() {
        if (msgIndex != -1) _messages[msgIndex] = _messages[msgIndex].copyAccepted(true);
      });
      _saveHistory();
      _checkPop();
    });
  }

  void _favFood(FoodItem food) {
    HapticFeedback.lightImpact();
    ref.read(foodActionsProvider).toggleFavorite(food);
    final favs = ref.read(favoritesProvider).value ?? [];
    final isFav = favs.any((f) => f.name.toLowerCase() == food.name.toLowerCase());
    _showSnackbar(isFav
        ? '${food.name} removed from favourites'
        : '${food.name} saved to favourites ★');
  }

  void _logAll() {
    final pending = _messages.where((m) =>
        m.type == _MsgType.foodCard && m.accepted == null).toList();
    for (final msg in pending) {
      if (msg.food != null) {
        if (msg.isCustomMealDraft && msg.draftIngredients != null) {
           _acceptFood(msg.food!, originalId: msg.food!.id);
        } else {
          final food = msg.noAiUsed
              ? msg.food!.copyWith(isAiLogged: false)
              : msg.food!.copyWith(isAiLogged: true);
          ref.read(foodActionsProvider).logFood(food);
        }
      }
    }
    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].type == _MsgType.foodCard &&
            _messages[i].accepted == null) {
          _messages[i] = _messages[i].copyAccepted(true);
        }
      }
    });
    _saveHistory();
    _showSnackbar('All items logged! ✓');
    Navigator.pop(context);
  }

  void _denyFood(FoodItem food) {
    HapticFeedback.lightImpact();
    setState(() {
      final i = _messages.indexWhere((m) => m.food?.id == food.id);
      if (i != -1) _messages[i] = _messages[i].copyAccepted(false);
    });
    _saveHistory();
    _checkPop();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackbar(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? Colors.redAccent.withOpacity(0.9) : AppTheme.accent.withOpacity(0.9),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final height      = MediaQuery.of(context).size.height * 0.92;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isSearchActive = _searchController.text.isNotEmpty;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Text('🪄', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Smart Logger',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                _UsageChip(used: _logsUsed, limitReached: _limitReached),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Normal food logging is unlimited. Credits are only used when AI helps identify meals, photos, or complex foods.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Or search food directly…',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accent)))
                    : const Icon(Icons.search_rounded,
                        color: AppTheme.textSecondary, size: 20),
                suffixIcon: isSearchActive
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() { _searchResults = []; _hasSearched = false; });
                        })
                    : null,
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 4),
          const Divider(color: AppTheme.surface, height: 16),

          Expanded(
            child: Builder(builder: (_) {
              final pendingCount = _messages
                  .where((m) => m.type == _MsgType.foodCard && m.accepted == null)
                  .length;
              return Stack(
                children: [
                  if (isSearchActive)
                    _SearchResultsList(
                      results: _searchResults,
                      isLoading: _isSearching,
                      hasSearched: _hasSearched,
                      onTap: _onSearchFoodTapped,
                    )
                  else if (_messages.isEmpty)
                    const _EmptyChat()
                  else
                    ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 8, 16,
                          pendingCount >= 2 ? 68 : 8),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) return const _TypingIndicator();
                        final msg = _messages[i];
                        if (msg.type == _MsgType.user)
                          return _UserBubble(text: msg.text!);
                        if (msg.type == _MsgType.error)
                          return _ErrorBubble(text: msg.text!);
                        if (msg.type == _MsgType.foodCard) {
                          final favs = ref.watch(favoritesProvider).value ?? [];
                          final isFav = favs.any((f) =>
                              f.name.toLowerCase() == msg.food!.name.toLowerCase());
                          return _FoodCardMsg(
                            food: msg.food!,
                            accepted: msg.accepted,
                            isFavorite: isFav,
                            noAiUsed: msg.noAiUsed,
                            isCustomMealDraft: msg.isCustomMealDraft,
                            onAccept: (food) => _acceptFood(food, originalId: msg.food!.id),
                            onEdit:   () => _editFood(msg.food!),
                            onFav:    () => _favFood(msg.food!),
                            onDeny:   () => _denyFood(msg.food!),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  if (!isSearchActive && pendingCount >= 2)
                    Positioned(
                      bottom: 8, left: 40, right: 40,
                      child: ElevatedButton.icon(
                        onPressed: _logAll,
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: Text('Log All ($pendingCount items)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.background,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),


          Container(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, bottomInset > 0 ? bottomInset : 24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              border:
                  Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: _limitReached
                ? _LimitBanner()
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? '🎤 Listening…'
                                : 'e.g. "3 rotis with dal and sabzi" or /custommeal',
                            hintStyle: TextStyle(
                                color: _isListening
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary,
                                fontSize: 13),
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.camera_alt_outlined,
                                      color: AppTheme.textSecondary),
                                  onPressed: _pickPhoto,
                                  tooltip: 'Log from photo',
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isListening
                                        ? Icons.mic_rounded
                                        : Icons.mic_none_rounded,
                                    color: _isListening
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary,
                                  ),
                                  onPressed: _toggleVoice,
                                  tooltip: 'Log by voice',
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: AppTheme.background, size: 20),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  final List<FoodItem> results;
  final bool isLoading;
  final bool hasSearched;
  final ValueChanged<FoodItem> onTap;

  const _SearchResultsList({
    required this.results, required this.isLoading,
    required this.hasSearched, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (hasSearched && results.isEmpty) {
      return const Center(
        child: Text('No results found.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final food = results[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          title: Text(food.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${food.protein}g P  •  ${food.carbs}g C  •  ${food.fats}g F',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          trailing: Text('${food.calories} kcal',
              style: const TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.bold)),
          onTap: () => onTap(food),
        );
      },
    );
  }
}

class _UsageChip extends StatelessWidget {
  final int used;
  final bool limitReached;
  const _UsageChip({required this.used, required this.limitReached});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: limitReached
              ? Colors.redAccent.withOpacity(0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: limitReached
                  ? Colors.redAccent.withOpacity(0.5)
                  : Colors.transparent),
        ),
        child: Text('Nutrition AI Assists: ${(10 - used).clamp(0, 10)} remaining',
            style: TextStyle(
              color: limitReached ? Colors.redAccent : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            )),
      );
}

class _LimitBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: Colors.redAccent, size: 16),
            SizedBox(width: 8),
            Text('Daily limit reached (10/10). Resets tomorrow.',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ),
      );
}

enum _MsgType { user, foodCard, error }

class _ChatMessage {
  final _MsgType type;
  final String?  text;
  final FoodItem? food;
  final bool?    accepted;
  final DateTime timestamp;
  final bool noAiUsed;
  final bool isCustomMealDraft;
  final List<CustomMealIngredient>? draftIngredients;

  const _ChatMessage({
    required this.type,
    this.text,
    this.food,
    this.accepted,
    required this.timestamp,
    this.noAiUsed = false,
    this.isCustomMealDraft = false,
    this.draftIngredients,
  });

  factory _ChatMessage.user(String t) =>
      _ChatMessage(type: _MsgType.user, text: t, timestamp: DateTime.now());
      
  factory _ChatMessage.foodCard(FoodItem f, {bool noAiUsed = false, bool isCustomMealDraft = false, List<CustomMealIngredient>? draftIngredients}) =>
      _ChatMessage(
        type: _MsgType.foodCard, 
        food: f, 
        timestamp: DateTime.now(), 
        noAiUsed: noAiUsed, 
        isCustomMealDraft: isCustomMealDraft, 
        draftIngredients: draftIngredients
      );
      
  factory _ChatMessage.error(String t) =>
      _ChatMessage(type: _MsgType.error, text: t, timestamp: DateTime.now());

  _ChatMessage copyAccepted(bool v, {FoodItem? newFood}) =>
      _ChatMessage(
        type: type, 
        text: text, 
        food: newFood ?? food, 
        accepted: v, 
        timestamp: timestamp, 
        noAiUsed: noAiUsed,
        isCustomMealDraft: isCustomMealDraft,
        draftIngredients: draftIngredients,
      );

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'text': text,
      'food': food?.toMap(),
      'accepted': accepted,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'noAiUsed': noAiUsed,
      'isCustomMealDraft': isCustomMealDraft,
      'draftIngredients': draftIngredients?.map((x) => {
        'foodId': x.foodId,
        'name': x.name,
        'amount': x.amount,
        'unit': x.unit,
        'calories': x.calories,
        'protein': x.protein,
        'carbs': x.carbs,
        'fats': x.fats,
        'baseAmount': x.baseAmount,
        'baseCal': x.baseCal,
        'basePro': x.basePro,
        'baseCarb': x.baseCarb,
        'baseFat': x.baseFat,
      }).toList(),
    };
  }

  factory _ChatMessage.fromMap(Map<String, dynamic> map) {
    return _ChatMessage(
      type: _MsgType.values.byName(map['type']),
      text: map['text'],
      food: map['food'] != null ? FoodItem.fromMap(Map<String, dynamic>.from(map['food'])) : null,
      accepted: map['accepted'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      noAiUsed: map['noAiUsed'] ?? false,
      isCustomMealDraft: map['isCustomMealDraft'] ?? false,
      draftIngredients: map['draftIngredients'] != null
        ? (map['draftIngredients'] as List).map((x) => CustomMealIngredient(
            foodId: x['foodId'],
            name: x['name'],
            amount: (x['amount'] as num).toDouble(),
            unit: x['unit'],
            calories: (x['calories'] as num).toInt(),
            protein: (x['protein'] as num).toInt(),
            carbs: (x['carbs'] as num).toInt(),
            fats: (x['fats'] as num).toInt(),
            baseAmount: (x['baseAmount'] as num).toDouble(),
            baseCal: (x['baseCal'] as num).toInt(),
            basePro: (x['basePro'] as num).toInt(),
            baseCarb: (x['baseCarb'] as num).toInt(),
            baseFat: (x['baseFat'] as num).toInt(),
          )).toList()
        : null,
    );
  }
}

class _SmartLoggerHistory {
  static const _keyPrefix = 'smart_logger_history_';

  static Future<void> saveMessages(String date, List<_ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded = messages.map((m) => jsonEncode(m.toMap())).toList();
    await prefs.setStringList('$_keyPrefix$date', encoded);
    await _cleanupOldHistory(prefs);
  }

  static Future<List<_ChatMessage>> loadMessages(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encoded = prefs.getStringList('$_keyPrefix$date');
    if (encoded == null) return [];
    return encoded.map((s) => _ChatMessage.fromMap(jsonDecode(s))).toList();
  }

  static Future<void> _cleanupOldHistory(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
    if (keys.length <= 7) return;

    keys.sort();

    final keysToRemove = keys.sublist(0, keys.length - 7);
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      );
}

class _ErrorBubble extends StatelessWidget {
  final String text;
  const _ErrorBubble({required this.text});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(text,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ),
      );
}

class _FoodCardMsg extends ConsumerStatefulWidget {
  final FoodItem food;
  final bool? accepted;
  final bool isFavorite;
  final bool noAiUsed;
  final bool isCustomMealDraft;
  final ValueChanged<FoodItem> onAccept;
  final VoidCallback onEdit;
  final VoidCallback onFav;
  final VoidCallback onDeny;

  const _FoodCardMsg({
    required this.food,
    required this.accepted,
    this.isFavorite = false,
    this.noAiUsed = false,
    this.isCustomMealDraft = false,
    required this.onAccept,
    required this.onEdit,
    required this.onFav,
    required this.onDeny,
  });

  @override
  ConsumerState<_FoodCardMsg> createState() => _FoodCardMsgState();
}

class _FoodCardMsgState extends ConsumerState<_FoodCardMsg> {
  late OilLevel _oilLevel;
  late FoodItem _adjustedFood;
  late bool _isOily;

  @override
  void initState() {
    super.initState();
    _isOily = isOilyIndianFood(widget.food.name);
    _oilLevel = OilLevel.normal;
    _adjustedFood = widget.food;
    if (_isOily) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final saved = ref.read(oilPreferenceProvider);
        final level = saved[widget.food.name.toLowerCase()] ?? OilLevel.normal;
        setState(() {
          _oilLevel = level;
          _adjustedFood = applyOilLevel(widget.food, level);
        });
      });
    }
  }

  void _onOilChanged(OilLevel level) {
    setState(() {
      _oilLevel = level;
      _adjustedFood = applyOilLevel(widget.food, level);
    });
    ref.read(oilPreferenceProvider.notifier).set(widget.food.name, level);
  }

  @override
  Widget build(BuildContext context) {
    final food = _adjustedFood;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 24),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: widget.accepted == null
                ? Colors.white.withValues(alpha: 0.08)
                : widget.accepted!
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : Colors.redAccent.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (!widget.noAiUsed && !widget.isCustomMealDraft)
                const Text('🪄 ', style: TextStyle(fontSize: 13)),
              Expanded(child: Text(food.name,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold))),
              Text(
                '${food.consumedAmount % 1 == 0 ? food.consumedAmount.toInt() : food.consumedAmount} ${food.consumedUnit}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ]),

            if (widget.isCustomMealDraft) ...[
               const SizedBox(height: 4),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: AppTheme.accent.withOpacity(0.15),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: const Text('CUSTOM MEAL PREVIEW', style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
               ),
            ] else if (widget.noAiUsed) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'No AI used ✓',
                  style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],

            const SizedBox(height: 10),
            if (_isOily && widget.accepted == null) ...[
              const SizedBox(height: 10),
              OilLevelPills(
                value: _oilLevel,
                onChanged: _onOilChanged,
              ),
            ],

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MacroBadge('${food.calories}', 'kcal', AppTheme.accent),
                _MacroBadge('${food.protein}g', 'Protein', Colors.blueAccent),
                _MacroBadge('${food.carbs}g', 'Carbs', Colors.orangeAccent),
                _MacroBadge('${food.fats}g', 'Fats', Colors.purpleAccent),
              ],
            ),
            if (widget.accepted == null) ...[
              const SizedBox(height: 12),
              Row(children: [
                _SmallBtn(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: Colors.white70,
                  onTap: widget.onEdit,
                ),
                const SizedBox(width: 6),
                _SmallBtn(
                  icon: widget.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: widget.isFavorite ? 'Saved' : 'Fav',
                  color: widget.isFavorite ? AppTheme.accent : Colors.amberAccent,
                  onTap: widget.onFav,
                ),
                const Spacer(),
                _SmallBtn(
                  icon: Icons.close_rounded,
                  label: 'Deny',
                  color: Colors.redAccent,
                  onTap: widget.onDeny,
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => widget.onAccept(_adjustedFood),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Log',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    elevation: 0,
                  ),
                ),
              ]),
            ] else ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(widget.accepted! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: widget.accepted! ? AppTheme.accent : Colors.redAccent,
                    size: 16),
                const SizedBox(width: 6),
                Text(widget.accepted! ? 'Logged / Saved' : 'Dismissed',
                    style: TextStyle(
                        color: widget.accepted! ? AppTheme.accent : Colors.redAccent,
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MacroBadge(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ]);
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🪄', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('Describe your meal, take a photo, or speak.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('"3 rotis with dal and sabzi"',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Text('"/aionly large biryani from Behrouz"',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Text('"/custommeal \"W Shake\" 2 banana, 250ml milk"',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🪄', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              SizedBox(width: 40,
                  child: LinearProgressIndicator(
                      color: AppTheme.accent,
                      backgroundColor: AppTheme.surface)),
            ],
          ),
        ),
      );
}