import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';

/// Reusable pace selector used in Onboarding Step 2 and Profile > Edit Goals.
/// Shows 5 pace chips, a live projection card, and a "set manually" toggle.
class GoalPaceSlider extends StatefulWidget {
  final double weight;
  final double goalWeight;
  final double tdee;
  final String initialPace;
  final ValueChanged<String> onPaceChanged;
  final ValueChanged<int> onCaloriesChanged;

  const GoalPaceSlider({
    super.key,
    required this.weight,
    required this.goalWeight,
    required this.tdee,
    required this.initialPace,
    required this.onPaceChanged,
    required this.onCaloriesChanged,
  });

  @override
  State<GoalPaceSlider> createState() => _GoalPaceSliderState();
}

class _GoalPaceSliderState extends State<GoalPaceSlider> {
  static const _paces  = ['very_slow','slow','moderate','fast','aggressive'];
  static const _labels = ['Very Slow','Slow','Moderate','Fast','Aggressive'];
  static const _emojis = ['🐢','🚶','🏃','⚡','🔥'];

  late String _pace;
  bool _manualMode = false;
  late TextEditingController _manualCtrl;

  @override
  void initState() {
    super.initState();
    _pace = _paces.contains(widget.initialPace) ? widget.initialPace : 'moderate';
    _manualCtrl = TextEditingController(text: _targetCals(_pace).toString());
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onCaloriesChanged(_targetCals(_pace)));
  }

  @override
  void dispose() { _manualCtrl.dispose(); super.dispose(); }

  bool get _isMaintain => widget.goalWeight == widget.weight;
  bool get _isLosing   => widget.goalWeight < widget.weight;

  int _targetCals(String pace) {
    final d = UserProfile.paceDelta(pace);
    double t;
    if (_isMaintain)    t = widget.tdee;
    else if (_isLosing) t = widget.tdee - d;
    else                t = widget.tdee + (d * 0.6);
    return t.clamp(1200, 4000).round();
  }

  double _weeklyKg(String pace) => UserProfile.weeklyChangeKg(pace);

  int _weeksToGoal(String pace) {
    final diff = (widget.goalWeight - widget.weight).abs();
    if (diff <= 0) return 0;
    final w = _weeklyKg(pace);
    return w > 0 ? (diff / w).ceil() : 0;
  }

  void _selectPace(String p) {
    setState(() { _pace = p; _manualCtrl.text = _targetCals(p).toString(); });
    widget.onPaceChanged(p);
    widget.onCaloriesChanged(_targetCals(p));
  }

  @override
  Widget build(BuildContext context) {
    final cals   = _manualMode
        ? (int.tryParse(_manualCtrl.text) ?? _targetCals(_pace))
        : _targetCals(_pace);
    final weekly = _weeklyKg(_pace);
    final weeks  = _weeksToGoal(_pace);
    final sign   = _isLosing ? '-' : (_isMaintain ? '±' : '+');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Pace chips ────────────────────────────────────────────────────
      if (!_manualMode) ...[
        Wrap(spacing: 8, runSpacing: 8,
          children: List.generate(_paces.length, (i) {
            final p = _paces[i];
            final sel = _pace == p;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); _selectPace(p); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? AppTheme.accent : Colors.white.withOpacity(0.08),
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_emojis[i], style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(_labels[i], style: TextStyle(
                    color: sel ? AppTheme.accent : AppTheme.textSecondary,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  )),
                ]),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // ── Projection card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
          ),
          child: Column(children: [
            _ProjRow(icon: Icons.local_fire_department_rounded,
                label: 'Target Calories', value: '$cals kcal/day',
                color: Colors.orangeAccent),
            const SizedBox(height: 10),
            _ProjRow(icon: Icons.trending_down_rounded,
                label: 'Weekly Change',
                value: '$sign${weekly.toStringAsFixed(2)} kg/week',
                color: _isLosing ? Colors.redAccent : Colors.greenAccent),
            if (!_isMaintain) ...[
              const SizedBox(height: 10),
              _ProjRow(icon: Icons.flag_rounded,
                  label: 'Goal in ~', value: '$weeks weeks',
                  color: AppTheme.accent),
            ],
          ]),
        ),
      ],

      // ── Manual mode ───────────────────────────────────────────────────
      if (_manualMode) ...[
        TextField(
          controller: _manualCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Target Calories (kcal/day)',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            suffixText: 'kcal',
            suffixStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true, fillColor: AppTheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
            ),
          ),
          onChanged: (v) {
            final c = int.tryParse(v) ?? 0;
            if (c > 0) widget.onCaloriesChanged(c);
          },
        ),
        const SizedBox(height: 10),
        Text('Auto macro split will be applied.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],

      const SizedBox(height: 12),

      // ── Toggle ────────────────────────────────────────────────────────
      GestureDetector(
        onTap: () => setState(() => _manualMode = !_manualMode),
        child: Row(children: [
          Icon(_manualMode ? Icons.tune_rounded : Icons.edit_rounded,
              size: 14, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            _manualMode ? 'Use pace selector instead' : 'Set calories manually',
            style: const TextStyle(color: AppTheme.accent,
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    ]);
  }
}

class _ProjRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ProjRow({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    const Spacer(),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
  ]);
}
