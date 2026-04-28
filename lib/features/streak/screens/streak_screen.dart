import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../nutrition/providers/nutrition_provider.dart';
import '../../nutrition/models/food_item.dart';

// ── GLOBAL DEBUG PROVIDER (Riverpod 3.0 Safe) ────────────────────────
class DebugStreakLevelNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void cycle() {
    if (state == null) {
      state = 0;
    } else if (state! >= 5) {
      state = null;
    } else {
      state = state! + 1;
    }
  }
}

final debugStreakLevelProvider = NotifierProvider<DebugStreakLevelNotifier, int?>(DebugStreakLevelNotifier.new);

final streakProvider = FutureProvider<StreakData>((ref) async {
  // Re-calculate whenever today's meals change so the home screen badge
  // and streak screen update immediately after logging food.
  ref.watch(nutritionProvider);
  return StreakService.calculate(ref);
});

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final debugLevel = ref.watch(debugStreakLevelProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Consistency Streak',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  // ── DEBUG BUTTON ─────────────────────────────────────────
                  Tooltip(
                    message: 'Debug 3D Models',
                    child: IconButton(
                      icon: Icon(
                        debugLevel == null ? Icons.bug_report_outlined : Icons.bug_report,
                        color: debugLevel == null ? AppTheme.textSecondary : AppTheme.accent,
                      ),
                      onPressed: () => ref.read(debugStreakLevelProvider.notifier).cycle(),
                    ),
                  ),
                ],
              ),
            ),
            if (debugLevel != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.accent.withOpacity(0.2),
                child: Text(
                  'DEBUG MODE: Forcing Level $debugLevel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: streakAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
                data: (streak) {
                  final displayLevel = debugLevel ?? streak.level;
                  
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // ── Reusable 3D Widget ──
                        SizedBox(
                          width: 300, 
                          height: 140, 
                          child: FitMe3DModel(level: displayLevel)
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'drag to view from any angle',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(StreakService._labels[displayLevel],
                            style: const TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Text('${streak.currentStreak}',
                            style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900, height: 1)),
                        const Text('day streak',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (streak.daysToNextLevel > 0)
                          Text('${streak.daysToNextLevel} more days to ${streak.nextLevelLabel}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            _StatCard(label: 'Longest', value: '${streak.longestStreak}d', color: AppTheme.accent),
                            const SizedBox(width: 12),
                            _StatCard(label: 'This Week', value: '${streak.daysHitThisWeek}/7', color: Colors.blueAccent),
                            const SizedBox(width: 12),
                            _StatCard(label: 'This Month', value: '${streak.daysHitThisMonth}d', color: Colors.purpleAccent),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Align(alignment: Alignment.centerLeft, child: Text('Progress to Next Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                        const SizedBox(height: 12),
                        _LevelProgressBar(streak: streak),
                        const SizedBox(height: 28),
                        const Align(alignment: Alignment.centerLeft, child: Text('Last 4 Weeks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                        const SizedBox(height: 12),
                        _WeeklyGrid(hitDays: streak.hitDays),
                        const SizedBox(height: 28),
                        const Align(alignment: Alignment.centerLeft, child: Text('Progression Levels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                        const SizedBox(height: 12),
                        _ProgressionLevels(currentLevel: displayLevel),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRUE 3D RENDER ENGINE
// ═══════════════════════════════════════════════════════════════════════════

class V3 {
  double x, y, z;
  V3(this.x, this.y, this.z);
}

class Face {
  final List<V3> vertices;
  final Color baseColor;
  final String? label;
  final double? radius;
  
  List<V3> projected = [];
  double centerZ = 0;
  bool visible = true;
  Color renderColor = Colors.black;

  Face(this.vertices, this.baseColor, {this.label, this.radius}) {
    projected = List.generate(vertices.length, (_) => V3(0,0,0));
  }
}

class True3DGeometry {
  static const Color silver = Color(0xFFF5F5F5);
  static const Color darkIron = Color(0xFF7A7A7A);
  static const Color plateRed = Color(0xFFFF3B30);
  static const Color plateBlue = Color(0xFF0A84FF);
  static const Color plateGreen = Color(0xFF32D74B);

  static void _addCylinder(List<Face> faces, double xCenter, double length, double radius, Color color, {int segments = 24, String? labelLeft, String? labelRight}) {
    double half = length / 2;
    List<V3> leftCircle = [];
    List<V3> rightCircle = [];
    
    for (int i = 0; i < segments; i++) {
      double a = i * 2 * math.pi / segments;
      double y = radius * math.cos(a);
      double z = radius * math.sin(a);
      leftCircle.add(V3(xCenter - half, y, z));
      rightCircle.add(V3(xCenter + half, y, z));
    }

    faces.add(Face(leftCircle.reversed.toList(), color, label: labelLeft, radius: radius));
    faces.add(Face(rightCircle.toList(), color, label: labelRight, radius: radius));

    for (int i = 0; i < segments; i++) {
      int next = (i + 1) % segments;
      faces.add(Face([leftCircle[i], rightCircle[i], rightCircle[next], leftCircle[next]], color));
    }
  }

  static List<Face> build(int level) {
    List<Face> faces = [];
    if (level == 0) {
      _addCylinder(faces, 0.0, 0.28, 0.05, darkIron);
      _addCylinder(faces, -0.18, 0.08, 0.16, darkIron, labelLeft: "FITME");
      _addCylinder(faces, 0.18, 0.08, 0.16, darkIron, labelRight: "FITME");
    } else if (level == 1) {
      _addCylinder(faces, 0.0, 0.26, 0.04, silver);
      _addCylinder(faces, -0.15, 0.04, 0.22, darkIron); 
      _addCylinder(faces, -0.19, 0.04, 0.22, darkIron, labelLeft: "FITME"); 
      _addCylinder(faces, -0.22, 0.02, 0.10, silver);
      _addCylinder(faces, 0.15, 0.04, 0.22, darkIron); 
      _addCylinder(faces, 0.19, 0.04, 0.22, darkIron, labelRight: "FITME"); 
      _addCylinder(faces, 0.22, 0.02, 0.10, silver);
    } else {
      _addCylinder(faces, 0.0, 1.0, 0.035, silver);
      _addCylinder(faces, -0.52, 0.04, 0.07, silver);
      _addCylinder(faces, 0.52, 0.04, 0.07, silver);

      if (level >= 3) {
        _addCylinder(faces, -0.57, 0.06, 0.40, plateRed, labelLeft: level == 3 ? "FITME" : null); 
        _addCylinder(faces, 0.57, 0.06, 0.40, plateRed, labelRight: level == 3 ? "FITME" : null);  
      }
      if (level >= 4) {
        _addCylinder(faces, -0.63, 0.05, 0.40, plateBlue, labelLeft: level == 4 ? "FITME" : null); 
        _addCylinder(faces, 0.63, 0.05, 0.40, plateBlue, labelRight: level == 4 ? "FITME" : null);  
      }
      if (level >= 5) {
        _addCylinder(faces, -0.68, 0.04, 0.40, plateGreen); 
        _addCylinder(faces, 0.68, 0.04, 0.40, plateGreen);  
        _addCylinder(faces, -0.73, 0.04, 0.40, plateGreen, labelLeft: "FITME"); 
        _addCylinder(faces, 0.73, 0.04, 0.40, plateGreen, labelRight: "FITME");  
      }

      double outerSleeveStart = level == 2 ? 0.54 : (level == 3 ? 0.60 : (level == 4 ? 0.66 : 0.75));
      double sleeveLength = 0.95 - outerSleeveStart;
      double sleeveCenter = outerSleeveStart + (sleeveLength / 2);
      
      _addCylinder(faces, -sleeveCenter, sleeveLength, 0.05, silver);
      _addCylinder(faces, sleeveCenter, sleeveLength, 0.05, silver);
    }
    return faces;
  }
}

class FitMe3DModel extends StatefulWidget {
  final int level;
  final double angleX;
  final double angleY;
  final bool interactive;
  final bool autoRotate;
  final bool drawText;
  final bool drawWireframe;

  const FitMe3DModel({
    required this.level,
    this.angleX = -0.3,
    this.angleY = -0.5,
    this.interactive = true,
    this.autoRotate = true,
    this.drawText = true,
    this.drawWireframe = true,
    super.key,
  });

  @override
  State<FitMe3DModel> createState() => _FitMe3DModelState();
}

class _FitMe3DModelState extends State<FitMe3DModel> with SingleTickerProviderStateMixin {
  late double _angleX;
  late double _angleY;
  late List<Face> _faces;
  
  AnimationController? _idleCtrl;
  Animation<double>? _idleAnim;
  bool _dragging = false;
  
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _angleXAtStart = 0;
  double _angleYAtStart = 0;

  @override
  void initState() {
    super.initState();
    _angleX = widget.angleX;
    _angleY = widget.angleY;
    _faces = True3DGeometry.build(widget.level); 
    
    if (widget.autoRotate) {
      _idleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
      _idleAnim = Tween<double>(begin: widget.angleY - 0.25, end: widget.angleY + 0.25).animate(CurvedAnimation(parent: _idleCtrl!, curve: Curves.easeInOut));
    }
  }

  @override
  void didUpdateWidget(covariant FitMe3DModel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _faces = True3DGeometry.build(widget.level); 
    }
    if (!widget.interactive) {
      _angleX = widget.angleX;
      _angleY = widget.angleY;
    }
  }

  @override
  void dispose() {
    _idleCtrl?.dispose();
    super.dispose();
  }

  void _panStart(DragStartDetails d) {
    if (!widget.interactive) return;
    _dragging = true;
    _idleCtrl?.stop();
    _dragStartX = d.localPosition.dx;
    _dragStartY = d.localPosition.dy;
    _angleXAtStart = _angleX;
    _angleYAtStart = _angleY;
  }

  void _panUpdate(DragUpdateDetails d) {
    if (!widget.interactive) return;
    setState(() {
      _angleY = _angleYAtStart + (d.localPosition.dx - _dragStartX) * 0.015;
      _angleX = _angleXAtStart + (d.localPosition.dy - _dragStartY) * 0.015;
    });
  }

  void _panEnd(DragEndDetails _) {
    if (!widget.interactive) return;
    _dragging = false;
    _idleAnim = Tween<double>(begin: _angleY - 0.2, end: _angleY + 0.2).animate(CurvedAnimation(parent: _idleCtrl!, curve: Curves.easeInOut));
    _idleCtrl?.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    Widget paintWidget;

    // We MUST use an AnimatedBuilder if autoRotate is true, otherwise the frames never get drawn!
    if (widget.autoRotate && _idleAnim != null && !_dragging) {
      paintWidget = AnimatedBuilder(
        animation: _idleAnim!,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: True3DPainter(
              faces: _faces,
              angleX: _angleX,
              angleY: _idleAnim!.value,
              drawText: widget.drawText,
              drawWireframe: widget.drawWireframe,
            ),
          );
        },
      );
    } else {
      paintWidget = CustomPaint(
        size: Size.infinite,
        painter: True3DPainter(
          faces: _faces,
          angleX: _angleX,
          angleY: _angleY,
          drawText: widget.drawText,
          drawWireframe: widget.drawWireframe,
        ),
      );
    }

    if (!widget.interactive) return paintWidget;

    return GestureDetector(
      onPanStart: _panStart,
      onPanUpdate: _panUpdate,
      onPanEnd: _panEnd,
      child: Container(
        color: Colors.transparent, 
        child: paintWidget,
      ),
    );
  }
}

class True3DPainter extends CustomPainter {
  final List<Face> faces;
  final double angleX;
  final double angleY;
  final bool drawText;
  final bool drawWireframe;

  static final Map<String, TextPainter> _textCache = {};

  True3DPainter({
    required this.faces,
    required this.angleX,
    required this.angleY,
    required this.drawText,
    required this.drawWireframe,
  });

  V3 _rotate(V3 p) {
    double cosY = math.cos(angleY), sinY = math.sin(angleY);
    double x1 = p.x * cosY + p.z * sinY, z1 = -p.x * sinY + p.z * cosY;
    double cosX = math.cos(angleX), sinX = math.sin(angleX);
    double y2 = p.y * cosX - z1 * sinX, z2 = p.y * sinX + z1 * cosX;
    return V3(x1, y2, z2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    V3 lightDir = V3(-0.5, -1.0, -0.8);
    double lightLen = math.sqrt(lightDir.x*lightDir.x + lightDir.y*lightDir.y + lightDir.z*lightDir.z);
    lightDir.x /= lightLen; lightDir.y /= lightLen; lightDir.z /= lightLen;

    List<Face> renderFaces = List.from(faces); 

    for (var face in renderFaces) {
      for (int i = 0; i < face.vertices.length; i++) {
        face.projected[i] = _rotate(face.vertices[i]);
      }

      V3 p0 = face.projected[0], p1 = face.projected[1], p2 = face.projected[2];
      V3 u = V3(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z);
      V3 v = V3(p2.x - p0.x, p2.y - p0.y, p2.z - p0.z);
      
      V3 normal = V3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x);
      double nLen = math.sqrt(normal.x*normal.x + normal.y*normal.y + normal.z*normal.z);
      if (nLen > 0) { normal.x /= nLen; normal.y /= nLen; normal.z /= nLen; }

      face.visible = normal.z <= 0;
      if (!face.visible) continue;

      double dot = -(normal.x * lightDir.x + normal.y * lightDir.y + normal.z * lightDir.z);
      double intensity = 0.65 + 0.55 * dot.clamp(0.0, 1.0); 

      face.renderColor = Color.fromARGB(
        255,
        (face.baseColor.red * intensity).round().clamp(0, 255),
        (face.baseColor.green * intensity).round().clamp(0, 255),
        (face.baseColor.blue * intensity).round().clamp(0, 255),
      );

      double sumZ = 0;
      for (var v in face.projected) sumZ += v.z;
      face.centerZ = sumZ / face.projected.length;
    }

    renderFaces.removeWhere((f) => !f.visible);
    renderFaces.sort((a, b) => b.centerZ.compareTo(a.centerZ));

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width * 0.45;
    
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = Colors.black.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 0.5;

    for (var face in renderFaces) {
      Path path = Path();
      path.moveTo(cx + face.projected[0].x * scale, cy + face.projected[0].y * scale);
      for (int i = 1; i < face.projected.length; i++) {
        path.lineTo(cx + face.projected[i].x * scale, cy + face.projected[i].y * scale);
      }
      path.close();

      fillPaint.color = face.renderColor;
      canvas.drawPath(path, fillPaint);
      if (drawWireframe) canvas.drawPath(path, strokePaint);

      if (drawText && face.label != null && face.radius != null) {
        double cxFace = 0, cyFace = 0;
        for (var v in face.projected) { cxFace += v.x; cyFace += v.y; }
        cxFace = cx + (cxFace / face.projected.length) * scale;
        cyFace = cy + (cyFace / face.projected.length) * scale;

        canvas.save();
        canvas.translate(cxFace, cyFace);
        double sx = math.max(0.01, math.sin(angleY).abs()); 
        double sy = math.max(0.01, math.cos(angleX).abs());
        canvas.scale(sx, sy);

        double pixelRadius = face.radius! * scale * 0.70; 
        double fontSize = math.max(1.0, pixelRadius * 0.45); 

        void drawArc(String text, bool isTop) {
          final totalAngle = math.pi * 0.65;
          final startAngle = isTop ? -totalAngle / 2 : totalAngle / 2;
          final endAngle = isTop ? totalAngle / 2 : -totalAngle / 2;
          
          for (int i = 0; i < text.length; i++) {
            final char = text[i];
            final fraction = text.length > 1 ? i / (text.length - 1) : 0.5;
            final angle = startAngle + fraction * (endAngle - startAngle);
            
            final cacheKey = '$char-${fontSize.round()}';
            TextPainter? tp = _textCache[cacheKey];
            if (tp == null) {
              tp = TextPainter(
                text: TextSpan(text: char, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: fontSize, fontWeight: FontWeight.w900, fontFamily: 'Arial')), 
                textDirection: TextDirection.ltr
              )..layout();
              _textCache[cacheKey] = tp;
            }

            canvas.save();
            canvas.rotate(angle);
            canvas.translate(0, isTop ? -pixelRadius : pixelRadius);
            tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
            canvas.restore();
          }
        }

        drawArc(face.label!, true);  
        drawArc(face.label!, false); 
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(True3DPainter old) => old.angleX != angleX || old.angleY != angleY;
}

class _LevelProgressBar extends StatelessWidget {
  final StreakData streak;
  const _LevelProgressBar({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: streak.levelProgress, backgroundColor: AppTheme.surface, color: AppTheme.accent, minHeight: 10),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(streak.levelLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text('${(streak.levelProgress * 100).round()}%', style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(streak.nextLevelLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _WeeklyGrid extends StatelessWidget {
  final Set<String> hitDays;
  const _WeeklyGrid({required this.hitDays});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final cells = List.generate(28, (i) {
      final week = i ~/ 7, day = i % 7;
      final date = monday.subtract(Duration(days: (3 - week) * 7)).add(Duration(days: day));
      final key = FoodItem.dateFor(date);
      return (hit: hitDays.contains(key), isToday: FoodItem.dateFor(date) == FoodItem.dateFor(now));
    });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dayLabels.map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)))).toList(),
        ),
        const SizedBox(height: 6),
        ...List.generate(
          4,
          (week) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (day) {
                final cell = cells[week * 7 + day];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: cell.hit ? AppTheme.accent.withOpacity(0.85) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: cell.isToday ? Border.all(color: AppTheme.accent, width: 2) : null,
                  ),
                  child: cell.hit ? const Icon(Icons.check_rounded, color: AppTheme.background, size: 16) : null,
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressionLevels extends StatelessWidget {
  final int currentLevel;
  const _ProgressionLevels({required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: StreakService._labels.asMap().entries.map((entry) {
        final idx = entry.key, label = entry.value;
        final isUnlocked = currentLevel >= idx, isCurrent = currentLevel == idx;
        
        String durationText = '';
        if (idx == 0) durationText = '0–7 days';
        else if (idx == 1) durationText = '8–21 days';
        else if (idx == 2) durationText = '22–44 days';
        else if (idx == 3) durationText = '45–89 days';
        else if (idx == 4) durationText = '90–179 days';
        else durationText = '180+ days';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCurrent ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isCurrent ? AppTheme.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              ClipRect(
                child: SizedBox(
                  width: 64, height: 36,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 300, 
                      height: 120, 
                      child: FitMe3DModel(level: idx, angleX: -0.2, angleY: -0.4, interactive: false, autoRotate: false)
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: isUnlocked ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                    Text(durationText, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Current', style: TextStyle(color: AppTheme.background, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else if (isUnlocked)
                const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 20)
              else
                const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary, size: 20),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class StreakData {
  final int currentStreak, longestStreak, daysHitThisWeek, daysHitThisMonth;
  final Set<String> hitDays;
  final int level;
  final String levelLabel, nextLevelLabel;
  final int daysToNextLevel;
  final double levelProgress;

  const StreakData({
    required this.currentStreak, required this.longestStreak, required this.daysHitThisWeek, required this.daysHitThisMonth,
    required this.hitDays, required this.level, required this.levelLabel, required this.nextLevelLabel,
    required this.daysToNextLevel, required this.levelProgress,
  });
}

class StreakService {
  static const _thresholds = [0, 8, 22, 45, 90, 180];
  static const _labels = ['Light Dumbbell', 'Heavy Dumbbell', 'Barbell', '1-Plate Barbell', '2-Plate Barbell', '4-Plate Barbell'];

  static Future<StreakData> calculate(Ref ref) async {
    final now = DateTime.now();
    final hitDays = <String>{};

    // ── Load historical hit days from Firestore ──────────────────────────
    // We query the last 200 days in a single Firestore request using a
    // dateString range — same collection that NutritionRepository uses.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        final cutoff = FoodItem.dateFor(now.subtract(const Duration(days: 200)));
        final today  = FoodItem.dateFor(now);

        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('logs')
            .where('dateString', isGreaterThanOrEqualTo: cutoff)
            .where('dateString', isLessThanOrEqualTo: today)
            // Only pull the two fields we need — avoids over-fetching macro data.
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final dateStr = data['dateString'] as String?;
          final name    = (data['name'] as String? ?? '').toLowerCase();
          // A day counts only when it has at least one real food entry
          // (not just a water tap).
          if (dateStr != null && name != 'water') {
            hitDays.add(dateStr);
          }
        }
      }
    } catch (e) {
      debugPrint('[StreakService] Firestore read error: $e');
      // Graceful fallback: at minimum count today if meals are in memory.
      final todayMeals = ref.read(nutritionProvider).value ?? [];
      if (todayMeals.any((m) => m.name.toLowerCase() != 'water')) {
        hitDays.add(FoodItem.dateFor(now));
      }
    }

    // ── Calculate current & longest streaks ──────────────────────────────
    int current = 0, longest = 0, temp = 0;
    for (int i = 0; i < 200; i++) {
      final key = FoodItem.dateFor(now.subtract(Duration(days: i)));
      if (hitDays.contains(key)) {
        temp++;
        if (i == 0) current = temp; // today logged → run starts/continues
        if (temp > longest) longest = temp;
      } else {
        if (i == 0) current = 0; // today not logged → streak is 0
        temp = 0;
      }
    }

    final monday = now.subtract(Duration(days: now.weekday - 1));
    int weekHits = 0, monthHits = 0;
    for (int i = 0; i < 7; i++) {
      if (hitDays.contains(FoodItem.dateFor(monday.add(Duration(days: i))))) weekHits++;
    }
    for (int i = 0; i < 30; i++) {
      if (hitDays.contains(FoodItem.dateFor(now.subtract(Duration(days: i))))) monthHits++;
    }

    int level = 0;
    for (int i = _thresholds.length - 1; i >= 0; i--) {
      if (current >= _thresholds[i]) { level = i; break; }
    }

    final nextLevel = (level + 1).clamp(0, 5);
    final nextThreshold = _thresholds[nextLevel], currentThreshold = _thresholds[level];
    final progress = nextLevel == level
        ? 1.0
        : (current - currentThreshold) / (nextThreshold - currentThreshold);

    return StreakData(
      currentStreak: current, longestStreak: longest,
      daysHitThisWeek: weekHits, daysHitThisMonth: monthHits,
      hitDays: hitDays, level: level,
      levelLabel: _labels[level],
      nextLevelLabel: _labels[nextLevel.clamp(0, 5)],
      daysToNextLevel: (nextThreshold - current).clamp(0, 999),
      levelProgress: progress.clamp(0.0, 1.0),
    );
  }
}