import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:fitme/core/theme/app_theme.dart';
import 'package:fitme/features/nutrition/models/food_item.dart';
import 'package:fitme/features/nutrition/providers/nutrition_provider.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/auth/screens/login_screen.dart';
import 'package:fitme/features/nutrition/services/food_search_service.dart';
import 'package:fitme/features/nutrition/services/food_knowledge_resolver.dart';
import 'package:fitme/features/nutrition/services/gemini_service.dart';
import 'package:fitme/features/insights/services/ai_usage_service.dart';
import 'package:fitme/features/nutrition/models/custom_meal_ingredient.dart';
import 'package:fitme/features/nutrition/services/custom_meal_service.dart';
import 'package:fitme/features/nutrition/screens/quantity_selection_screen.dart';
import 'package:fitme/features/nutrition/widgets/custom_meal_form.dart';
import 'package:fitme/features/nutrition/widgets/barcode_scanner_screen.dart';
import 'package:fitme/features/nutrition/widgets/smart_logger_components.dart';

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
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLogging = false;
  bool _isListening = false;
  bool _isResolving = false;
  bool _isGuest = false;

  String? _activeStreamId;
  Timer? _saveDebounce;
  final Set<String> _currentlyLoggingIds = {};

  // Search overlay state
  bool _isSearching = false;
  List<FoodItem> _searchResults = [];
  bool _hasSearched = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _checkGuestStatus();
  }

  void _checkGuestStatus() {
    final isGuest = ref.read(isGuestProvider);
    setState(() => _isGuest = isGuest);
  }

  Future<void> _loadHistory() async {
    final date = FoodItem.dateFor(DateTime.now());
    final history = await SmartLoggerHistory.loadMessages(date);
    if (mounted) {
      setState(() => _messages = history);
      _scrollToBottom();
    }
  }

  Future<void> _saveHistory() async {
    final date = FoodItem.dateFor(DateTime.now());
    await SmartLoggerHistory.saveMessages(date, _messages);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _saveDebounce?.cancel();
    _speech.cancel();
    super.dispose();
  }

  void _triggerDebouncedSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), _saveHistory);
  }

  Future<void> _appendMessagesStaggered(List<ChatMessage> items, String streamId) async {
    if (items.isEmpty) return;
    final interval = (400 ~/ items.length).clamp(80, 150);
    for (final item in items) {
      if (!mounted || _activeStreamId != streamId) break;
      setState(() {
        _messages.add(item);
      });
      _scrollToBottom();
      _triggerDebouncedSave();
      await Future.delayed(Duration(milliseconds: interval));
    }
  }

  int get _maxLimit {
    final isGuest = ref.read(isGuestProvider);
    return isGuest ? kGuestMonthlyLimit : kAuthDailyLimit;
  }

  int get _remainingUses {
    return ref.watch(remainingAiUsesProvider).value ?? _maxLimit;
  }

  bool get _limitReached => _remainingUses <= 0;

  // ── CORE LOGIC ─────────────────────────────────────────────────────────────

  void _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending || _limitReached) return;

    HapticFeedback.lightImpact();
    _inputController.clear();
    final streamId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeStreamId = streamId;

    setState(() {
      _messages.add(ChatMessage.user(text));
      _isSending = true;
      _isResolving = true;
    });
    _scrollToBottom();

    try {
      final lowerText = text.toLowerCase();
      if (lowerText.startsWith('/custommeal')) {
        await _handleCustomMealCommand(text, streamId);
      } else if (lowerText.startsWith('/aionly')) {
        if (_isGuest) {
          _showAiLockCard(hint: text.replaceFirst(RegExp(r'/aionly\s*', caseSensitive: false), '').trim());
        } else {
          await _handleAiOnlyCommand(text, streamId);
        }
      } else {
        await _parseNaturalLanguage(text, streamId);
      }
    } catch (e) {
      if (mounted && _activeStreamId == streamId) {
        setState(() {
          _messages.add(ChatMessage.error('Sorry, something went wrong.'));
        });
      }
    } finally {
      if (mounted && _activeStreamId == streamId) {
        setState(() {
          _isSending = false;
          _isResolving = false;
        });
      }
    }
    _triggerDebouncedSave();
    _scrollToBottom();
  }

  Future<void> _handleCustomMealCommand(String text, String streamId) async {
    final regex = RegExp(r'/custommeal\s+"([^"]+)"\s*(.*)', caseSensitive: false);
    final match = regex.firstMatch(text);

    if (match == null) {
      if (mounted && _activeStreamId == streamId) {
        setState(() {
          _messages.add(ChatMessage.error('Format: /custommeal "Name" ingredients...'));
        });
      }
      return;
    }

    final name = match.group(1)!;
    final ingredientsText = match.group(2)!.trim();

    if (ingredientsText.isEmpty) {
      if (mounted && _activeStreamId == streamId) {
        setState(() {
          _messages.add(ChatMessage.error('Please provide ingredients for "$name".'));
        });
      }
      return;
    }

    final foods = await GeminiService.parseFood('Ingredients for "$name": $ingredientsText');
    if (!mounted || _activeStreamId != streamId) return;

    if (foods.isNotEmpty) {
      final summary = FoodItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        calories: foods.fold(0, (sum, f) => sum + f.calories),
        protein: foods.fold(0, (sum, f) => sum + f.protein),
        carbs: foods.fold(0, (sum, f) => sum + f.carbs),
        fats: foods.fold(0, (sum, f) => sum + f.fats),
        consumedAmount: 1,
        consumedUnit: 'serving',
      );
      
      final draftIngs = foods.map((m) => CustomMealIngredient(
          foodId: m.id,
          name: m.name,
          amount: m.consumedAmount,
          unit: m.consumedUnit,
          calories: m.calories,
          protein: m.protein,
          carbs: m.carbs,
          fats: m.fats,
          baseAmount: m.consumedAmount,
          baseCal: m.calories,
          basePro: m.protein,
          baseCarb: m.carbs,
          baseFat: m.fats,
        )).toList();

      setState(() {
        _messages.add(ChatMessage.foodCard(summary, isCustomMealDraft: true, draftIngredients: draftIngs));
      });
    } else {
      setState(() {
        _messages.add(ChatMessage.error('Could not parse ingredients.'));
      });
    }
  }

  Future<void> _handleAiOnlyCommand(String text, String streamId) async {
    final query = text.replaceFirst(RegExp(r'/aionly\s*', caseSensitive: false), '').trim();
    if (query.isEmpty) {
      if (mounted && _activeStreamId == streamId) {
        setState(() => _messages.add(ChatMessage.error('Format: /aionly food description...')));
      }
      return;
    }

    final foods = await GeminiService.parseFoodSafe(query);
    if (!mounted || _activeStreamId != streamId) return;

    if (foods.isNotEmpty) {
      await ref.read(foodActionsProvider).incrementSmartLoggerCount();
      final msgs = foods.map((f) => ChatMessage.foodCard(f)).toList();
      await _appendMessagesStaggered(msgs, streamId);
    } else {
      setState(() => _messages.add(ChatMessage.error('Could not identify that even with AI.')));
    }
  }

  Future<void> _parseNaturalLanguage(String text, String streamId) async {
    final customs = ref.read(customMealsProvider).value ?? [];
    final common = ref.read(commonFoodsProvider).value ?? [];
    final recents = ref.read(recentsProvider).value ?? [];

    final parsed = await FoodKnowledgeResolver.parseMeal(
      input: text,
      customs: customs,
      commonFoods: common,
      recents: recents,
      allowAi: !_isGuest,
    );
    
    if (!mounted || _activeStreamId != streamId) return;

    List<ChatMessage> localMsgs = [];
    bool anyAiNeeded = false;
    for (final seg in parsed.segments) {
      if (seg.isResolved) {
        localMsgs.add(ChatMessage.foodCard(seg.resolvedFood!, noAiUsed: true));
      } else {
        anyAiNeeded = true;
      }
    }

    if (localMsgs.isNotEmpty) {
      await _appendMessagesStaggered(localMsgs, streamId);
    }

    if (anyAiNeeded) {
      if (_isGuest) {
        _showAiLockCard(
          hint: parsed.segments.where((s) => !s.isResolved).map((s) => s.rawInput).join(', '),
        );
      } else {
        if (!mounted || _activeStreamId != streamId) return;
        setState(() => _isResolving = true);
        
        final aiFoods = await GeminiService.parseFoodSafe(text);
        if (!mounted || _activeStreamId != streamId) return;
        
        if (aiFoods.isNotEmpty) {
          await ref.read(foodActionsProvider).incrementSmartLoggerCount();
          final aiMsgs = aiFoods
              .where((f) => !_messages.any((m) => m.food?.name.toLowerCase() == f.name.toLowerCase()))
              .map((f) => ChatMessage.foodCard(f))
              .toList();
          await _appendMessagesStaggered(aiMsgs, streamId);
        } else if (_messages.isEmpty || _messages.last.type == MsgType.user) {
          setState(() => _messages.add(ChatMessage.error('Could not identify some items. Try searching manually.')));
        }
      }
    }
  }

  void _onSearchChanged(String val) async {
    _searchDebounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final customs = ref.read(customMealsProvider).value ?? [];
      final common = ref.read(commonFoodsProvider).value ?? [];
      final recents = ref.read(recentsProvider).value ?? [];
      final favs = ref.read(favoritesProvider).value ?? [];

      final result = await FoodSearchService.logSheetSearch(
        query: val,
        customMeals: customs,
        commonFoods: common,
        recents: recents,
        favorites: favs,
      );
      if (mounted) {
        setState(() {
          _searchResults = result.foods;
          _isSearching = false;
        });
      }
    });
  }

  void _onSearchFoodTapped(FoodItem food) {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
      _isSearching = false;
    });
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuantitySelectionScreen(baseFood: food)));
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

  Future<void> _acceptFood(FoodItem food, {required String originalId, bool fromLogAll = false}) async {
    // If called internally from Log All, we bypass the main _isLogging guard
    if ((_isLogging && !fromLogAll) || _currentlyLoggingIds.contains(originalId)) return;

    if (!fromLogAll) setState(() => _isLogging = true);
    _currentlyLoggingIds.add(originalId);

    try {
      final msgIndex = _messages.indexWhere((m) => m.food?.id == originalId && m.accepted == null);
      if (msgIndex != -1) {
        final msg = _messages[msgIndex];
        
        if (msg.isCustomMealDraft && msg.draftIngredients != null) {
          final customs = ref.read(customMealsProvider).value ?? [];
          String finalName = food.name;
          int counter = 1;
          while (customs.any((c) => c.name.toLowerCase() == finalName.toLowerCase())) {
             finalName = '${food.name} ($counter)';
             counter++;
          }

          final toLog = food.copyWith(name: finalName, isAiLogged: !msg.noAiUsed);
          await ref.read(foodActionsProvider).logFood(toLog);
          
          final draft = CustomMealDraft(
            name: finalName,
            servings: 1,
            ingredients: msg.draftIngredients!,
            notes: '',
          );
          await CustomMealService.create(draft);
          if (!fromLogAll) _showSnackbar('Meal "$finalName" Logged & Saved! ✓');
          
          if (mounted) {
            setState(() {
              _messages[msgIndex] = _messages[msgIndex].copyAccepted(true, newFood: toLog);
            });
          }
        } else {
          final toLog = food.copyWith(isAiLogged: !msg.noAiUsed);
          await ref.read(foodActionsProvider).logFood(toLog);
          if (mounted) {
            setState(() {
              _messages[msgIndex] = _messages[msgIndex].copyAccepted(true);
            });
          }
        }
      }
      
      ref.invalidate(nutritionProvider);
      ref.invalidate(dailyTotalsProvider);
      if (!fromLogAll) _checkPop();
      
    } catch(e) {
        if (mounted) _showSnackbar('Failed to log: $e', error: true);
    } finally {
      if (mounted) {
        _currentlyLoggingIds.remove(originalId);
        if (!fromLogAll) setState(() => _isLogging = false);
      }
    }
    if (!fromLogAll) _triggerDebouncedSave();
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
        _triggerDebouncedSave();
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
      _triggerDebouncedSave();
      _checkPop();
    });
  }

  void _favFood(FoodItem food) async {
    HapticFeedback.lightImpact();
    await ref.read(foodActionsProvider).toggleFavorite(food);
    final favs = ref.read(favoritesProvider).value ?? [];
    final isFav = favs.any((f) => f.name.toLowerCase() == food.name.toLowerCase());
    _showSnackbar(isFav ? '${food.name} removed from favourites' : '${food.name} saved to favourites ★');
    _triggerDebouncedSave();
  }

  void _denyFood(FoodItem food) {
    HapticFeedback.lightImpact();
    setState(() {
      final idx = _messages.indexWhere((m) => m.food?.id == food.id && m.accepted == null);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyAccepted(false);
      }
    });
    _triggerDebouncedSave();
    _checkPop();
  }

  void _toggleListening() async {
    if (_limitReached || _isSending) return;

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        HapticFeedback.mediumImpact();
        _speech.listen(
          onResult: (val) {
            setState(() => _inputController.text = val.recognizedWords);
            if (val.finalResult) {
              _toggleListening(); // Toggles off automatically
            }
          },
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_IN',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_inputController.text.isNotEmpty) _sendMessage();
    }
  }

  void _pickImage() async {
    if (_isResolving || _limitReached) return;
    HapticFeedback.lightImpact();

    if (_isGuest) {
      _showAiLockCard(hint: 'Identify food from photo');
      return;
    }

    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return;

    final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      final streamId = DateTime.now().millisecondsSinceEpoch.toString();
      _activeStreamId = streamId;

      setState(() {
        _isResolving = true;
        _messages.add(ChatMessage.user('📷 Photo submitted'));
      });
      _scrollToBottom();
      
      try {
        final foods = await GeminiService.parseFoodFromImage(File(image.path));
        if (!mounted || _activeStreamId != streamId) return;

        if (foods.isNotEmpty) {
          await ref.read(foodActionsProvider).incrementSmartLoggerCount();
          final msgs = foods.map((f) => ChatMessage.foodCard(f)).toList();
          await _appendMessagesStaggered(msgs, streamId);
        } else {
          setState(() => _messages.add(ChatMessage.error('Could not identify food from photo.')));
        }
      } finally {
        if (mounted && _activeStreamId == streamId) {
          setState(() => _isResolving = false);
        }
      }
      _triggerDebouncedSave();
    }
  }

  void _checkPop() {
    final pendingCount = _messages.where((m) => m.type == MsgType.foodCard && m.accepted == null).length;
    if (pendingCount == 0 && mounted) {
      Navigator.pop(context);
    }
  }

  void _logAll() async {
    if (_isLogging) return;

    final pending = _messages.where((m) => m.type == MsgType.foodCard && m.accepted == null).toList();
    if (pending.isEmpty) return;

    setState(() => _isLogging = true);

    try {
      for (final msg in pending) {
        if (!mounted) break;
        if (msg.food != null && !_currentlyLoggingIds.contains(msg.food!.id)) {
          // Send to standard _acceptFood internally bypassing the _isLogging check
          await _acceptFood(msg.food!, originalId: msg.food!.id, fromLogAll: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLogging = false);
        _showSnackbar('All items logged! ✓');
        Navigator.pop(context);
      }
    }
    _triggerDebouncedSave();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent.withValues(alpha: 0.9) : AppTheme.accent.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    final isSearchActive = _searchController.text.isNotEmpty;
    final favs = ref.watch(favoritesProvider).value ?? [];

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(2))
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Text('🪄', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Smart Logger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                UsageChip(
                  used: _maxLimit - _remainingUses,
                  limitReached: _limitReached,
                  isGuest: _isGuest,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Normal food logging is unlimited. Credits are only used when AI helps identify meals, photos, or complex foods.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),

          // ── TOP SEARCH BAR WITH BARCODE ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search food…',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
                    : const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSearchActive)
                      IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() { _searchResults = []; _hasSearched = false; _isSearching = false; });
                          }),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textSecondary, size: 20),
                      onPressed: _openBarcodeScanner,
                      tooltip: 'Scan barcode',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 4),
          const Divider(color: AppTheme.surface, height: 16),

          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final pendingCount = _messages.where((m) => m.type == MsgType.foodCard && m.accepted == null).length;
                return Stack(
                  children: [
                    if (isSearchActive)
                      SearchResultsList(
                        results: _searchResults,
                        isLoading: _isSearching,
                        hasSearched: _hasSearched,
                        onTap: _onSearchFoodTapped,
                      )
                    else if (_messages.isEmpty)
                      const EmptyChat()
                    else
                      ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 8, 16, pendingCount >= 2 ? 68 : 8),
                        itemCount: _messages.length + (_isResolving ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _messages.length) return const RepaintBoundary(child: TypingIndicator());
                          
                          final msg = _messages[i];
                          if (msg.type == MsgType.user) return RepaintBoundary(child: UserBubble(text: msg.text!));
                          if (msg.type == MsgType.error) return ErrorBubble(text: msg.text!);
                          
                          if (msg.type == MsgType.aiLock) {
                            return RepaintBoundary(
                              child: AiLockCard(
                                hint: msg.text,
                                onSignIn: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                              ),
                            );
                          }
                          
                          if (msg.type == MsgType.foodCard) {
                            final isFav = favs.any((f) => f.name.toLowerCase() == msg.food!.name.toLowerCase());
                            return RepaintBoundary(
                              child: FoodCardMsg(
                                food: msg.food!,
                                accepted: msg.accepted,
                                isFavorite: isFav,
                                noAiUsed: msg.noAiUsed,
                                isCustomMealDraft: msg.isCustomMealDraft,
                                onAccept: (food) => _acceptFood(food, originalId: msg.food!.id),
                                onEdit: () => _editFood(msg.food!),
                                onFav: () => _favFood(msg.food!),
                                onDeny: () => _denyFood(msg.food!),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    
                    if (!isSearchActive && pendingCount >= 2)
                      Positioned(
                        bottom: 8, left: 40, right: 40,
                        child: RepaintBoundary(
                          child: ElevatedButton.icon(
                            onPressed: _logAll,
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: Text('Log All ($pendingCount items)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: AppTheme.background,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          // ── BOTTOM NLP TEXT FIELD ───────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? bottomInset : 24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_limitReached)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: LimitBanner(isGuest: _isGuest),
                  ),
                if (!isSearchActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RepaintBoundary(
                      child: CommandButtonRow(
                        isGuest: _isGuest,
                        onCustomMeal: () {
                          _inputController.text = '/custommeal "" ';
                          _inputController.selection = TextSelection.fromPosition(const TextPosition(offset: 13));
                        },
                        onAiOnly: () {
                          if (_isGuest) {
                            _showAiLockCard(hint: 'AI Search');
                            return;
                          }
                          _inputController.text = '/aionly ';
                          _inputController.selection = TextSelection.fromPosition(const TextPosition(offset: 8));
                        },
                      ),
                    ),
                  ),
                _limitReached
                    ? RepaintBoundary(child: LimitBanner(isGuest: _isGuest))
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              onSubmitted: (_) => _sendMessage(),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: 3,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: _isListening ? '🎤 Listening…' : '"oats banana" or /custommeal',
                                hintStyle: TextStyle(
                                  color: _isListening ? AppTheme.accent : AppTheme.textSecondary,
                                  fontSize: 13
                                ),
                                filled: true,
                                fillColor: AppTheme.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.textSecondary),
                                      onPressed: _pickImage,
                                      tooltip: 'Log from photo',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                        color: _isListening ? AppTheme.accent : AppTheme.textSecondary,
                                      ),
                                      onPressed: _toggleListening,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSendButton(),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = _inputController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: canSend ? _sendMessage : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: canSend ? AppTheme.accent : AppTheme.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send_rounded,
          color: canSend ? AppTheme.background : AppTheme.textSecondary,
          size: 20,
        ),
      ),
    );
  }

  void _showAiLockCard({String? hint}) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage.aiLock(hint: hint));
        _isResolving = false;
      });
    }
    _triggerDebouncedSave();
    _scrollToBottom();
  }
}