import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:fitme/core/theme/app_theme.dart';
import 'package:fitme/features/insights/services/ai_usage_service.dart';
import 'package:fitme/core/widgets/oil_level_selector.dart';
import 'package:fitme/features/nutrition/models/food_item.dart';
import 'package:fitme/features/nutrition/models/custom_meal_ingredient.dart';
import 'package:fitme/features/nutrition/providers/oil_level_provider.dart';

enum MsgType { user, foodCard, error, aiLock }

class ChatMessage {
  final String id;
  final MsgType type;
  final String? text;
  final FoodItem? food;
  final bool? accepted; // null = pending, true = accepted, false = denied
  final DateTime timestamp;
  final bool noAiUsed;
  final bool isCustomMealDraft;
  final List<CustomMealIngredient>? draftIngredients;

  ChatMessage({
    String? id,
    required this.type,
    this.text,
    this.food,
    this.accepted,
    DateTime? timestamp,
    this.noAiUsed = false,
    this.isCustomMealDraft = false,
    this.draftIngredients,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.user(String text) => ChatMessage(type: MsgType.user, text: text);
  factory ChatMessage.error(String text) => ChatMessage(type: MsgType.error, text: text);
  factory ChatMessage.aiLock({String? hint}) => ChatMessage(type: MsgType.aiLock, text: hint);
  
  factory ChatMessage.foodCard(FoodItem food, {bool noAiUsed = false, bool isCustomMealDraft = false, List<CustomMealIngredient>? draftIngredients}) =>
      ChatMessage(
        type: MsgType.foodCard, 
        food: food, 
        noAiUsed: noAiUsed, 
        isCustomMealDraft: isCustomMealDraft,
        draftIngredients: draftIngredients,
      );

  ChatMessage copyAccepted(bool val, {FoodItem? newFood}) => ChatMessage(
        id: id,
        type: type,
        text: text,
        food: newFood ?? food,
        accepted: val,
        timestamp: timestamp,
        noAiUsed: noAiUsed,
        isCustomMealDraft: isCustomMealDraft,
        draftIngredients: draftIngredients,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
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

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'],
        type: MsgType.values[map['type']],
        text: map['text'],
        food: map['food'] != null ? FoodItem.fromMap(Map<String, dynamic>.from(map['food'])) : null,
        accepted: map['accepted'],
        timestamp: map['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) : null,
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

class SmartLoggerHistory {
  static const _keyPrefix = 'smart_logger_history_';

  static Future<void> saveMessages(String date, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((m) => jsonEncode(m.toMap())).toList();
    await prefs.setStringList('$_keyPrefix$date', jsonList);
    await _cleanupOldHistory(prefs);
  }

  static Future<List<ChatMessage>> loadMessages(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('$_keyPrefix$date') ?? [];
    return jsonList.map((j) => ChatMessage.fromMap(jsonDecode(j))).toList();
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

// ── WIZARD UI & HINTS ────────────────────────────────────────────────────────

class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('🧙', style: TextStyle(fontSize: 44))),
            const SizedBox(height: 12),
            const Center(child: Text('Smart Logger',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(height: 4),
            const Center(child: Text('Describe meals in plain language — I\'ll find them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
            const SizedBox(height: 20),
            const HintSection(icon: '🍽️', title: 'Natural language', examples: [
              '50g oats banana peanut butter',
              '2 roti sabzi curd',
              'protein shake with milk and banana',
              '250ml milk + 1 scoop whey',
            ]),
            const SizedBox(height: 12),
            const HintSection(icon: '⚡', title: '/custommeal — create & save a meal', examples: [
              '/custommeal "Workout Shake" 250ml milk, 1 scoop whey, 1 banana',
              '/custommeal "Dal Rice" 1 katori dal, 1 katori rice',
            ]),
            const SizedBox(height: 12),
            const HintSection(icon: '🤖', title: '/aionly — force AI (auth only)', examples: [
              '/aionly large biryani from Behrouz',
              '/aionly homemade paneer sandwich',
            ]),
            const SizedBox(height: 8),
          ],
        ),
      );
}

class HintSection extends StatelessWidget {
  final String icon, title;
  final List<String> examples;
  
  const HintSection({super.key, required this.icon, required this.title, required this.examples});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
            const SizedBox(height: 8),
            ...examples.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(e, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, fontFamily: 'monospace')),
            )),
          ]
        ),
      );
}

// ── BUBBLES AND CARDS ────────────────────────────────────────────────────────

class UserBubble extends StatelessWidget {
  final String text;
  const UserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }
}

class ErrorBubble extends StatelessWidget {
  final String text;
  const ErrorBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🪄', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(color: AppTheme.accent, backgroundColor: AppTheme.surface),
            ),
          ],
        ),
      ),
    );
  }
}

class AiLockCard extends StatelessWidget {
  final String? hint;
  final VoidCallback onSignIn;

  const AiLockCard({super.key, this.hint, required this.onSignIn});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12, right: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4), topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.purpleAccent, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('AI Search — Sign In Required',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ]),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text('Couldn’t find locally: $hint',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          const Text(
            'Create a free account to unlock AI-powered food search, photo logging, and more.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onSignIn,
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Sign Up Free', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
          ),
        ],
      ),
    ),
  );
}

class FoodCardMsg extends ConsumerStatefulWidget {
  final FoodItem food;
  final bool? accepted;
  final bool isFavorite;
  final bool noAiUsed;
  final bool isCustomMealDraft;
  final Function(FoodItem) onAccept;
  final VoidCallback onEdit;
  final VoidCallback onFav;
  final VoidCallback onDeny;

  const FoodCardMsg({
    super.key,
    required this.food,
    required this.accepted,
    required this.isFavorite,
    required this.noAiUsed,
    required this.isCustomMealDraft,
    required this.onAccept,
    required this.onEdit,
    required this.onFav,
    required this.onDeny,
  });

  @override
  ConsumerState<FoodCardMsg> createState() => _FoodCardMsgState();
}

class _FoodCardMsgState extends ConsumerState<FoodCardMsg> {
  late OilLevel _oilLevel;
  late FoodItem _currentFood;
  late bool _isOily;

  @override
  void initState() {
    super.initState();
    _currentFood = widget.food;
    _isOily = isOilyIndianFood(widget.food.name);
    _oilLevel = OilLevel.normal;

    if (_isOily) {
      // SYNCHRONOUS READ: Prevents the double-rebuild lag issue on scroll
      final saved = ref.read(oilPreferenceProvider);
      final level = saved[widget.food.name.toLowerCase()] ?? OilLevel.normal;
      _oilLevel = level;
      _currentFood = applyOilLevel(widget.food, level);
    }
  }

  void _onOilChanged(OilLevel level) {
    setState(() {
      _oilLevel = level;
      _currentFood = applyOilLevel(widget.food, level);
    });
    ref.read(oilPreferenceProvider.notifier).set(widget.food.name, level);
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = widget.accepted == null;
    final bool isAccepted = widget.accepted == true;

    return Align(
      alignment: Alignment.centerLeft,
      child: Opacity(
        opacity: widget.accepted == false ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
              color: isPending
                  ? Colors.white.withValues(alpha: 0.08)
                  : isAccepted
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
                Expanded(
                  child: Text(
                    _currentFood.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_currentFood.consumedAmount % 1 == 0 ? _currentFood.consumedAmount.toInt() : _currentFood.consumedAmount} ${_currentFood.consumedUnit}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ]),

              if (widget.isCustomMealDraft) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('CUSTOM MEAL PREVIEW',
                      style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ),
              ] else if (widget.noAiUsed) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'No AI used ✓',
                    style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              if (_isOily && isPending) ...[
                const SizedBox(height: 10),
                OilLevelPills(value: _oilLevel, onChanged: _onOilChanged),
              ],

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MacroBadge('${_currentFood.calories}', 'kcal', AppTheme.accent),
                  _MacroBadge('${_currentFood.protein}g', 'Protein', Colors.blueAccent),
                  _MacroBadge('${_currentFood.carbs}g', 'Carbs', Colors.orangeAccent),
                  _MacroBadge('${_currentFood.fats}g', 'Fats', Colors.purpleAccent),
                ],
              ),
              if (isPending) ...[
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
                    icon: widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
                    onPressed: () => widget.onAccept(_currentFood),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                  ),
                ]),
              ] else ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isAccepted ? AppTheme.accent : Colors.redAccent,
                      size: 16),
                  const SizedBox(width: 6),
                  Text(isAccepted ? 'Logged / Saved' : 'Dismissed',
                      style: TextStyle(
                          color: isAccepted ? AppTheme.accent : Colors.redAccent,
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ],
            ],
          ),
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
  const _SmallBtn({required this.icon, required this.label, required this.color, required this.onTap});
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
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ── COMMAND ROW & PILLS ──────────────────────────────────────────────────────

class CommandButtonRow extends StatelessWidget {
  final bool isGuest;
  final VoidCallback onCustomMeal;
  final VoidCallback onAiOnly;

  const CommandButtonRow({
    super.key,
    required this.isGuest,
    required this.onCustomMeal,
    required this.onAiOnly,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
      children: [
        CommandPill(
          label: '⚡ /custommeal',
          tooltip: '/custommeal "Name" ingredients...',
          color: AppTheme.accent,
          onTap: onCustomMeal,
        ),
        const SizedBox(width: 8),
        CommandPill(
          label: isGuest ? '🔒 /aionly' : '🤖 /aionly',
          tooltip: isGuest ? 'Sign in to use AI search' : '/aionly food description...',
          color: isGuest ? AppTheme.textSecondary : Colors.purpleAccent,
          onTap: onAiOnly,
        ),
      ],
    ),
  );
}

class CommandPill extends StatelessWidget {
  final String label, tooltip;
  final Color color;
  final VoidCallback onTap;

  const CommandPill({
    super.key, 
    required this.label, 
    required this.tooltip, 
    required this.color, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
             BoxShadow(
               color: color.withValues(alpha: 0.1),
               blurRadius: 8,
               offset: const Offset(0, 2),
             ),
          ],
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: color, 
            fontSize: 13, 
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          )
        ),
      ),
    ),
  );
}

// ── UTILITIES ────────────────────────────────────────────────────────────────

class SearchResultsList extends StatelessWidget {
  final List<FoodItem> results;
  final bool isLoading;
  final bool hasSearched;
  final Function(FoodItem) onTap;

  const SearchResultsList({
    super.key,
    required this.results,
    required this.isLoading,
    required this.hasSearched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (hasSearched && results.isEmpty) {
      return const Center(
        child: Text('No results found.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: results.length,
      itemBuilder: (_, i) {
        final food = results[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${food.protein}g P  •  ${food.carbs}g C  •  ${food.fats}g F',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: Text('${food.calories} kcal',
              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          onTap: () => onTap(food),
        );
      },
    );
  }
}

class UsageChip extends StatelessWidget {
  final int used;
  final bool limitReached;
  final bool isGuest;
  const UsageChip({
    super.key,
    required this.used,
    required this.limitReached,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: limitReached ? Colors.redAccent.withValues(alpha: 0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: limitReached ? Colors.redAccent.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Text(
        isGuest
            ? 'Nutrition AI Assists: ${(kGuestMonthlyLimit - used).clamp(0, kGuestMonthlyLimit)} remaining this month'
            : 'Nutrition AI Assists: ${(kAuthDailyLimit - used).clamp(0, kAuthDailyLimit)} remaining today',
        style: TextStyle(
          color: limitReached ? Colors.redAccent : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class LimitBanner extends StatelessWidget {
  final bool isGuest;
  const LimitBanner({super.key, required this.isGuest});
  
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              isGuest
                  ? 'Monthly limit reached ($kGuestMonthlyLimit/$kGuestMonthlyLimit). Sign in for more!'
                  : 'Daily limit reached ($kAuthDailyLimit/$kAuthDailyLimit). Resets tomorrow.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ),
      );
}