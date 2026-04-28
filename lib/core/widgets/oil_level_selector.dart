import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../features/nutrition/providers/oil_level_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FULL SLIDER VARIANT  (used on quantity_selection & food_details screens)
// ─────────────────────────────────────────────────────────────────────────────
class OilLevelSelector extends StatelessWidget {
  final OilLevel value;
  final ValueChanged<OilLevel> onChanged;

  const OilLevelSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _labels = ['Light', 'Normal', 'Heavy'];
  static const _emojis = ['🥗', '🍛', '🧈'];
  static const _descriptions = [
    'Less oil / ghee',
    'Standard recipe',
    'Extra ghee / fried',
  ];

  Color _sliderColor(OilLevel level) {
    switch (level) {
      case OilLevel.light:  return const Color(0xFF00C7FF); // cyan – light
      case OilLevel.normal: return AppTheme.accent;          // orange – normal
      case OilLevel.heavy:  return const Color(0xFFFF453A); // red – heavy
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = value.index2;
    final activeColor = _sliderColor(value);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeColor.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Row(
            children: [
              const Text('🫕 ', style: TextStyle(fontSize: 15)),
              const Text(
                'Richness',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  '${_emojis[idx]}  ${_labels[idx]}',
                  key: ValueKey(idx),
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Slider ──────────────────────────────────────────────────────
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: activeColor,
              inactiveTrackColor: AppTheme.background,
              thumbColor: activeColor,
              overlayColor: activeColor.withOpacity(0.15),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
              activeTickMarkColor: activeColor.withOpacity(0.6),
              inactiveTickMarkColor: Colors.white.withOpacity(0.15),
            ),
            child: Slider(
              value: idx.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(OilLevelExt.fromIndex(v.round()));
              },
            ),
          ),

          // ── Tick labels ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(3, (i) {
                final isActive = i == idx;
                return Text(
                  _labels[i],
                  style: TextStyle(
                    color: isActive ? activeColor : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 8),

          // ── Description chip ────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(idx),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _descriptions[idx],
                style: TextStyle(
                  color: activeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT PILL VARIANT  (used on Smart Logger food cards)
// ─────────────────────────────────────────────────────────────────────────────
class OilLevelPills extends StatelessWidget {
  final OilLevel value;
  final ValueChanged<OilLevel> onChanged;

  const OilLevelPills({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _levels = [OilLevel.light, OilLevel.normal, OilLevel.heavy];
  static const _labels = ['🥗 Light', '🍛 Normal', '🧈 Heavy'];

  static const _colors = [
    Color(0xFF00C7FF),
    Color(0xFFFF9500),
    Color(0xFFFF453A),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final level = _levels[i];
        final isActive = value == level;
        final color = _colors[i];
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(level);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              padding:
                  const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.15) : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? color : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                _labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive ? color : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
