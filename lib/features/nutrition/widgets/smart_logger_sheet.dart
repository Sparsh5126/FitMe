import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../providers/nutrition_provider.dart';
import '../services/gemini_service.dart';
import '../../dashboard/providers/user_provider.dart';

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
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showFeatureTray = false;

  // Swipe to reveal feature tray
  double _dragOffset = 0;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _logsUsed {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return 0;
    // Reset if last reset date != today
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (profile.smartLoggerLastResetDate != today) return 0;
    return profile.smartLoggerUsedToday;
  }

  bool get _limitReached => _logsUsed >= 5;

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading || _limitReached) return;

    HapticFeedback.lightImpact();
    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage.user(text));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final foods = await GeminiService.parseFood(text);

      setState(() {
        _isLoading = false;
        if (foods.isEmpty) {
          _messages.add(_ChatMessage.error("Couldn't parse that. Try being more specific, e.g. '2 rotis with dal and sabzi'."));
        } else {
          for (final food in foods) {
            _messages.add(_ChatMessage.foodCard(food));
          }
          // Increment usage counter
          ref.read(nutritionProvider.notifier).incrementSmartLoggerCount();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage.error('Something went wrong. Try again.'));
      });
    }

    _scrollToBottom();
  }

  void _acceptFood(FoodItem food) {
    HapticFeedback.mediumImpact();
    ref.read(nutritionProvider.notifier).addFood(food.copyWith(isAiLogged: true));
    setState(() {
      final i = _messages.indexWhere((m) => m.food?.id == food.id);
      if (i != -1) _messages[i] = _messages[i].copyAccepted(true);
    });
    // Show celebration if enabled
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food.name} logged! ✓'),
        backgroundColor: AppTheme.accent.withOpacity(0.9),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _denyFood(FoodItem food) {
    HapticFeedback.lightImpact();
    setState(() {
      final i = _messages.indexWhere((m) => m.food?.id == food.id);
      if (i != -1) _messages[i] = _messages[i].copyAccepted(false);
    });
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

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        setState(() => _dragOffset += d.delta.dx);
        if (_dragOffset.abs() > 60) {
          setState(() {
            _showFeatureTray = true;
            _dragOffset = 0;
          });
        }
      },
      onHorizontalDragEnd: (_) => setState(() => _dragOffset = 0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showFeatureTray
            ? _FeatureTray(onClose: () => setState(() => _showFeatureTray = false))
            : _ChatUI(
                height: height,
                bottomInset: bottomInset,
                messages: _messages,
                logsUsed: _logsUsed,
                isLoading: _isLoading,
                limitReached: _limitReached,
                inputController: _inputController,
                scrollController: _scrollController,
                onSend: _sendMessage,
                onAccept: _acceptFood,
                onDeny: _denyFood,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHAT UI
// ─────────────────────────────────────────────
class _ChatUI extends StatelessWidget {
  final double height;
  final double bottomInset;
  final List<_ChatMessage> messages;
  final int logsUsed;
  final bool isLoading;
  final bool limitReached;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final ValueChanged<FoodItem> onAccept;
  final ValueChanged<FoodItem> onDeny;

  const _ChatUI({
    required this.height,
    required this.bottomInset,
    required this.messages,
    required this.logsUsed,
    required this.isLoading,
    required this.limitReached,
    required this.inputController,
    required this.scrollController,
    required this.onSend,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle + header
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🪄', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('Smart Logger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                // Usage counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: limitReached ? Colors.redAccent.withOpacity(0.15) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: limitReached ? Colors.redAccent.withOpacity(0.5) : Colors.transparent),
                  ),
                  child: Text(
                    '$logsUsed / 5 today',
                    style: TextStyle(
                      color: limitReached ? Colors.redAccent : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              '← swipe to access more features →',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),

          const Divider(color: AppTheme.surface, height: 16),

          // Messages
          Expanded(
            child: messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == messages.length) return const _TypingIndicator();
                      final msg = messages[i];
                      if (msg.type == _MsgType.user) return _UserBubble(text: msg.text!);
                      if (msg.type == _MsgType.error) return _ErrorBubble(text: msg.text!);
                      if (msg.type == _MsgType.foodCard) {
                        return _FoodCardMsg(
                          food: msg.food!,
                          accepted: msg.accepted,
                          onAccept: () => onAccept(msg.food!),
                          onDeny: () => onDeny(msg.food!),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
          ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset > 0 ? bottomInset : 24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: limitReached
                ? Container(
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
                        Text("Daily limit reached (5/5). Resets tomorrow.", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: inputController,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => onSend(),
                          decoration: InputDecoration(
                            hintText: 'e.g. "3 rotis with dal and sabzi"',
                            hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onSend,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.send_rounded, color: AppTheme.background, size: 20),
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

// ─────────────────────────────────────────────
// FEATURE TRAY
// ─────────────────────────────────────────────
class _FeatureTray extends StatelessWidget {
  final VoidCallback onClose;
  const _FeatureTray({required this.onClose});

  static const _features = [
    (Icons.restaurant_menu_rounded, 'Diet Plan', 'Design a personalized diet plan'),
    (Icons.analytics_rounded, 'Analyse Diet', 'Rate and analyse your eating habits'),
    (Icons.menu_book_rounded, 'Recipes', 'Get meal suggestions based on your macros'),
    (Icons.storefront_rounded, 'Store', 'Supplements & gear'),
    (Icons.people_rounded, 'Challenge', 'Challenge a friend to a fitness goal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: onClose,
                ),
                const SizedBox(width: 8),
                const Text('More Features', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _features.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final f = _features[i];
                return GestureDetector(
                  onTap: () {}, // TODO: route to each feature
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(f.$1, color: AppTheme.accent, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(f.$3, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHAT MESSAGE TYPES
// ─────────────────────────────────────────────
enum _MsgType { user, foodCard, error }

class _ChatMessage {
  final _MsgType type;
  final String? text;
  final FoodItem? food;
  final bool? accepted; // null = pending, true = accepted, false = denied

  const _ChatMessage({required this.type, this.text, this.food, this.accepted});

  factory _ChatMessage.user(String text) => _ChatMessage(type: _MsgType.user, text: text);
  factory _ChatMessage.foodCard(FoodItem food) => _ChatMessage(type: _MsgType.foodCard, food: food);
  factory _ChatMessage.error(String text) => _ChatMessage(type: _MsgType.error, text: text);

  _ChatMessage copyAccepted(bool value) => _ChatMessage(type: type, text: text, food: food, accepted: value);
}

// ─────────────────────────────────────────────
// CHAT BUBBLES
// ─────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.15),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  final String text;
  const _ErrorBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
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

class _FoodCardMsg extends StatelessWidget {
  final FoodItem food;
  final bool? accepted;
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const _FoodCardMsg({required this.food, required this.accepted, required this.onAccept, required this.onDeny});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
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
            color: accepted == null
                ? Colors.white.withOpacity(0.08)
                : accepted!
                    ? AppTheme.accent.withOpacity(0.5)
                    : Colors.redAccent.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🪄 ', style: TextStyle(fontSize: 13)),
                Expanded(child: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
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
            if (accepted == null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDeny,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Deny'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                      ),
                      child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(accepted! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: accepted! ? AppTheme.accent : Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(accepted! ? 'Logged' : 'Dismissed',
                      style: TextStyle(color: accepted! ? AppTheme.accent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MacroBadge(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🪄', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('Type your meal in plain English.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('"Had 2 eggs and toast for breakfast"', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text('"3 rotis with dal and sabzi"', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text('"Large biryani from Behrouz"', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

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