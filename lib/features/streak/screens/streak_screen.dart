import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/nutrition/models/food_item.dart';
import 'package:fitme/features/fitpoints/providers/fitpoints_provider.dart';
import 'package:fitme/features/fitpoints/models/fitpoints_models.dart';

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

final debugStreakLevelProvider =
    NotifierProvider<DebugStreakLevelNotifier, int?>(
      DebugStreakLevelNotifier.new,
    );

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(consistencySnapshotProvider);
    final debugLevel = ref.watch(debugStreakLevelProvider);
    final theme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.colors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Consistency Streak',
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  // ── DEBUG BUTTON ─────────────────────────────────────────
                  Tooltip(
                    message: 'Debug 3D Models',
                    child: IconButton(
                      icon: Icon(
                        debugLevel == null
                            ? Icons.bug_report_outlined
                            : Icons.bug_report,
                        color: debugLevel == null
                            ? theme.colors.textSecondary
                            : theme.colors.accent,
                      ),
                      onPressed: () =>
                          ref.read(debugStreakLevelProvider.notifier).cycle(),
                    ),
                  ),
                ],
              ),
            ),
            if (debugLevel != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: theme.colors.accent.withOpacity(0.2),
                child: Text(
                  'DEBUG MODE: Forcing Level $debugLevel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: snapshotAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: theme.colors.accent),
                ),
                error: (e, _) => Center(
                  child: Text('$e', style: const TextStyle(color: Colors.red)),
                ),
                data: (snap) {
                  final displayLevel =
                      debugLevel ?? _calculateLevel(snap.currentStreak);

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
                          child: FitMe3DModel(level: displayLevel),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'drag to view from any angle',
                          style: TextStyle(
                            color: theme.colors.textSecondary,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          debugLevel != null
                              ? StreakLevel.values[debugLevel].streakLabel
                                    .toUpperCase()
                              : snap.streakLevel.streakLabel.toUpperCase(),
                          style: TextStyle(
                            color: theme.colors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snap.currentStreak}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          'day streak',
                          style: TextStyle(
                            color: theme.colors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Days to next level
                        _buildNextLevelInfo(snap, theme),

                        const SizedBox(height: 36),
                        Row(
                          children: [
                            _StatCard(
                              label: 'Longest',
                              value: '${snap.longestStreak}d',
                              color: theme.colors.accent,
                              theme: theme,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              label: 'This Week',
                              value: '${snap.weeklyActiveDays}/7',
                              color: Colors.blueAccent,
                              theme: theme,
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              label: 'This Month',
                              value: '${snap.monthlyActiveDays}d',
                              color: Colors.purpleAccent,
                              theme: theme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Progress to Next Level',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _LevelProgressBar(snap: snap, theme: theme),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Last 4 Weeks',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _WeeklyGrid(hitDays: snap.hitDays, theme: theme),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Progression Levels',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProgressionLevels(
                          currentLevel: displayLevel,
                          theme: theme,
                        ),
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

  int _calculateLevel(int streak) {
    if (streak >= 180) return 5;
    if (streak >= 90) return 4;
    if (streak >= 45) return 3;
    if (streak >= 22) return 2;
    if (streak >= 8) return 1;
    return 0;
  }

  Widget _buildNextLevelInfo(ConsistencySnapshot snap, dynamic theme) {
    if (snap.streakLevel == StreakLevel.maxLevel) {
      return const SizedBox();
    }

    return Text(
      '${snap.daysToNextLevel} more days to ${snap.nextLevelLabel}',
      style: TextStyle(color: theme.colors.textSecondary, fontSize: 13),
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
    projected = List.generate(vertices.length, (_) => V3(0, 0, 0));
  }
}

class True3DGeometry {
  static const Color silverSleeve = Color(0xFFF5F5F5);
  static const Color darkIron = Color(0xFF7A7A7A);
  static const Color plateBronze = Color(0xFFCD7F32);
  static const Color plateSilver = Color(0xFFC0C0C0);
  static const Color plateGold = Color(0xFFFFD700);

  static void _addCylinder(
    List<Face> faces,
    double xCenter,
    double length,
    double radius,
    Color color, {
    int segments = 24,
    String? labelLeft,
    String? labelRight,
  }) {
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

    faces.add(
      Face(
        leftCircle.reversed.toList(),
        color,
        label: labelLeft,
        radius: radius,
      ),
    );
    faces.add(
      Face(rightCircle.toList(), color, label: labelRight, radius: radius),
    );

    for (int i = 0; i < segments; i++) {
      int next = (i + 1) % segments;
      faces.add(
        Face([
          leftCircle[i],
          rightCircle[i],
          rightCircle[next],
          leftCircle[next],
        ], color),
      );
    }
  }

  static List<Face> build(int level) {
    List<Face> faces = [];
    if (level == 0) {
      _addCylinder(faces, 0.0, 0.28, 0.05, darkIron);
      _addCylinder(faces, -0.18, 0.08, 0.16, darkIron, labelLeft: "FITME");
      _addCylinder(faces, 0.18, 0.08, 0.16, darkIron, labelRight: "FITME");
    } else if (level == 1) {
      _addCylinder(faces, 0.0, 0.26, 0.04, silverSleeve);
      _addCylinder(faces, -0.15, 0.04, 0.22, darkIron);
      _addCylinder(faces, -0.19, 0.04, 0.22, darkIron, labelLeft: "FITME");
      _addCylinder(faces, -0.22, 0.02, 0.10, silverSleeve);
      _addCylinder(faces, 0.15, 0.04, 0.22, darkIron);
      _addCylinder(faces, 0.19, 0.04, 0.22, darkIron, labelRight: "FITME");
      _addCylinder(faces, 0.22, 0.02, 0.10, silverSleeve);
    } else {
      _addCylinder(faces, 0.0, 1.0, 0.035, silverSleeve);
      _addCylinder(faces, -0.52, 0.04, 0.07, silverSleeve);
      _addCylinder(faces, 0.52, 0.04, 0.07, silverSleeve);

      final plateColor = level >= 5
          ? plateGold
          : level == 4
          ? plateSilver
          : plateBronze;

      if (level >= 3) {
        _addCylinder(
          faces,
          -0.57,
          0.06,
          0.40,
          plateColor,
          labelLeft: level == 3 ? "FITME" : null,
        );
        _addCylinder(
          faces,
          0.57,
          0.06,
          0.40,
          plateColor,
          labelRight: level == 3 ? "FITME" : null,
        );
      }
      if (level >= 4) {
        _addCylinder(
          faces,
          -0.63,
          0.05,
          0.40,
          plateColor,
          labelLeft: level == 4 ? "FITME" : null,
        );
        _addCylinder(
          faces,
          0.63,
          0.05,
          0.40,
          plateColor,
          labelRight: level == 4 ? "FITME" : null,
        );
      }
      if (level >= 5) {
        _addCylinder(faces, -0.68, 0.04, 0.40, plateColor);
        _addCylinder(faces, 0.68, 0.04, 0.40, plateColor);
        _addCylinder(faces, -0.73, 0.04, 0.40, plateColor, labelLeft: "FITME");
        _addCylinder(faces, 0.73, 0.04, 0.40, plateColor, labelRight: "FITME");
      }

      double outerSleeveStart = level == 2
          ? 0.54
          : (level == 3 ? 0.60 : (level == 4 ? 0.66 : 0.75));
      double sleeveLength = 0.95 - outerSleeveStart;
      double sleeveCenter = outerSleeveStart + (sleeveLength / 2);

      _addCylinder(faces, -sleeveCenter, sleeveLength, 0.05, silverSleeve);
      _addCylinder(faces, sleeveCenter, sleeveLength, 0.05, silverSleeve);
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

class _FitMe3DModelState extends State<FitMe3DModel>
    with SingleTickerProviderStateMixin {
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
      _idleCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      )..repeat(reverse: true);
      _idleAnim = Tween<double>(
        begin: widget.angleY - 0.25,
        end: widget.angleY + 0.25,
      ).animate(CurvedAnimation(parent: _idleCtrl!, curve: Curves.easeInOut));
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
    _idleAnim = Tween<double>(
      begin: _angleY - 0.2,
      end: _angleY + 0.2,
    ).animate(CurvedAnimation(parent: _idleCtrl!, curve: Curves.easeInOut));
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
      child: Container(color: Colors.transparent, child: paintWidget),
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
    double lightLen = math.sqrt(
      lightDir.x * lightDir.x +
          lightDir.y * lightDir.y +
          lightDir.z * lightDir.z,
    );
    lightDir.x /= lightLen;
    lightDir.y /= lightLen;
    lightDir.z /= lightLen;

    List<Face> renderFaces = List.from(faces);

    for (var face in renderFaces) {
      for (int i = 0; i < face.vertices.length; i++) {
        face.projected[i] = _rotate(face.vertices[i]);
      }

      V3 p0 = face.projected[0], p1 = face.projected[1], p2 = face.projected[2];
      V3 u = V3(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z);
      V3 v = V3(p2.x - p0.x, p2.y - p0.y, p2.z - p0.z);

      V3 normal = V3(
        u.y * v.z - u.z * v.y,
        u.z * v.x - u.x * v.z,
        u.x * v.y - u.y * v.x,
      );
      double nLen = math.sqrt(
        normal.x * normal.x + normal.y * normal.y + normal.z * normal.z,
      );
      if (nLen > 0) {
        normal.x /= nLen;
        normal.y /= nLen;
        normal.z /= nLen;
      }

      face.visible = normal.z <= 0;
      if (!face.visible) continue;

      double dot =
          -(normal.x * lightDir.x +
              normal.y * lightDir.y +
              normal.z * lightDir.z);
      double intensity = 0.65 + 0.55 * dot.clamp(0.0, 1.0);

      face.renderColor = Color.fromARGB(
        255,
        (face.baseColor.red * intensity).round().clamp(0, 255),
        (face.baseColor.green * intensity).round().clamp(0, 255),
        (face.baseColor.blue * intensity).round().clamp(0, 255),
      );

      double sumZ = 0;
      for (var v in face.projected) {
        sumZ += v.z;
      }
      face.centerZ = sumZ / face.projected.length;
    }

    renderFaces.removeWhere((f) => !f.visible);
    renderFaces.sort((a, b) => b.centerZ.compareTo(a.centerZ));

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width * 0.45;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (var face in renderFaces) {
      Path path = Path();
      path.moveTo(
        cx + face.projected[0].x * scale,
        cy + face.projected[0].y * scale,
      );
      for (int i = 1; i < face.projected.length; i++) {
        path.lineTo(
          cx + face.projected[i].x * scale,
          cy + face.projected[i].y * scale,
        );
      }
      path.close();

      fillPaint.color = face.renderColor;
      canvas.drawPath(path, fillPaint);
      if (drawWireframe) canvas.drawPath(path, strokePaint);

      if (drawText && face.label != null && face.radius != null) {
        double cxFace = 0, cyFace = 0;
        for (var v in face.projected) {
          cxFace += v.x;
          cyFace += v.y;
        }
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
                text: TextSpan(
                  text: char,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Arial',
                  ),
                ),
                textDirection: TextDirection.ltr,
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
  bool shouldRepaint(True3DPainter old) =>
      old.angleX != angleX || old.angleY != angleY;
}

class _LevelProgressBar extends StatelessWidget {
  final ConsistencySnapshot snap;
  final dynamic theme;
  const _LevelProgressBar({required this.snap, required this.theme});

  @override
  Widget build(BuildContext context) {
    final level = snap.streakLevel;
    final progress = snap.levelProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colors.surfacePrimary,
            color: theme.colors.accent,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              level.streakLabel,
              style: TextStyle(color: theme.colors.textSecondary, fontSize: 12),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: theme.colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              snap.nextLevelLabel,
              style: TextStyle(color: theme.colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyGrid extends StatelessWidget {
  final Set<String> hitDays;
  final dynamic theme;
  const _WeeklyGrid({required this.hitDays, required this.theme});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final cells = List.generate(28, (i) {
      final week = i ~/ 7, day = i % 7;
      final date = monday
          .subtract(Duration(days: (3 - week) * 7))
          .add(Duration(days: day));
      final key = FoodItem.dateFor(date);
      return (
        hit: hitDays.contains(key),
        isToday: FoodItem.dateFor(date) == FoodItem.dateFor(now),
      );
    });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dayLabels
              .map(
                (d) => SizedBox(
                  width: 36,
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              )
              .toList(),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cell.hit
                        ? theme.colors.accent.withOpacity(0.85)
                        : theme.colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(8),
                    border: cell.isToday
                        ? Border.all(color: theme.colors.accent, width: 2)
                        : null,
                  ),
                  child: cell.hit
                      ? Icon(
                          Icons.check_rounded,
                          color: theme.colors.backgroundPrimary,
                          size: 16,
                        )
                      : null,
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
  final dynamic theme;
  const _ProgressionLevels({required this.currentLevel, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: StreakLevel.values.asMap().entries.map((entry) {
        final idx = entry.key, level = entry.value;
        final isUnlocked = currentLevel >= idx, isCurrent = currentLevel == idx;

        String durationText = '';
        if (idx == 0) {
          durationText = '0–7 days';
        } else if (idx == 1) {
          durationText = '8–21 days';
        } else if (idx == 2) {
          durationText = '22–44 days';
        } else if (idx == 3) {
          durationText = '45–89 days';
        } else if (idx == 4) {
          durationText = '90–149 days';
        } else {
          durationText = '150+ days';
        }

        final label = level.streakLabel;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCurrent
                ? theme.colors.accent.withOpacity(0.1)
                : theme.colors.surfacePrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? theme.colors.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              ClipRect(
                child: SizedBox(
                  width: 64,
                  height: 36,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 300,
                      height: 120,
                      child: FitMe3DModel(
                        level: idx,
                        angleX: -0.2,
                        angleY: -0.4,
                        interactive: false,
                        autoRotate: false,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isUnlocked
                            ? theme.colors.textPrimary
                            : theme.colors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      durationText,
                      style: TextStyle(
                        color: theme.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      color: theme.colors.backgroundPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isUnlocked)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colors.accent,
                  size: 20,
                )
              else
                Icon(
                  Icons.lock_outline_rounded,
                  color: theme.colors.textSecondary,
                  size: 20,
                ),
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
  final dynamic theme;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
