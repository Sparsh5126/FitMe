# Graph Report - fitme  (2026-05-09)

## Corpus Check
- 105 files · ~103,940 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1089 nodes · 1365 edges · 35 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter_riverpod/flutter_riverpod.dart` - 36 edges
2. `package:flutter/material.dart` - 32 edges
3. `../../../core/theme/app_theme.dart` - 29 edges
4. `package:flutter/services.dart` - 24 edges
5. `package:firebase_auth/firebase_auth.dart` - 21 edges
6. `package:cloud_firestore/cloud_firestore.dart` - 19 edges
7. `../models/food_item.dart` - 17 edges
8. `../../../core/models/user_profile.dart` - 14 edges
9. `../../dashboard/providers/user_provider.dart` - 13 edges
10. `../../auth/providers/auth_provider.dart` - 11 edges

## Surprising Connections (you probably didn't know these)
- `fl_register_plugins()` --calls--> `my_application_activate()`  [INFERRED]
  linux\flutter\generated_plugin_registrant.cc → linux\runner\my_application.cc
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux\runner\main.cc → linux\runner\my_application.cc
- `RegisterPlugins()` --calls--> `OnCreate()`  [INFERRED]
  windows\flutter\generated_plugin_registrant.cc → windows\runner\flutter_window.cpp
- `OnCreate()` --calls--> `GetClientArea()`  [INFERRED]
  windows\runner\flutter_window.cpp → windows\runner\win32_window.cpp
- `OnCreate()` --calls--> `SetChildContent()`  [INFERRED]
  windows\runner\flutter_window.cpp → windows\runner\win32_window.cpp

## Communities

### Community 0 - "Community 0"
Cohesion: 0.03
Nodes (74): ../../../core/theme/app_theme.dart, AppTheme, ThemeData, build, dispose, _inputDecoration, _label, LoginScreen (+66 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (75): ../../auth/screens/login_screen.dart, ../../../core/models/exercise.dart, ../../../core/models/workout.dart, InsightsAggregationService, refresh, AiAnalysisNotifier, _AiUsageChip, build (+67 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (70): Challenge, ChallengeProgress, ConsistencyMetrics, copyWith, FitPointsRecord, FitPointTransaction, FpAwardResult, MealLogEntry (+62 more)

### Community 3 - "Community 3"
Cohesion: 0.03
Nodes (63): consistency_engine.dart, ../../../core/models/user_profile.dart, BackupService, BackupStatus, applyAward, awardPoints, _buildAwardReason, buildTransaction (+55 more)

### Community 4 - "Community 4"
Cohesion: 0.04
Nodes (53): barcode_scanner_screen.dart, custom_meal_form.dart, build, Container, _EmptyFavourites, FavoritesScreen, _FavTile, push (+45 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (55): _AiLockCard, Align, build, cancel, Center, _ChatMessage, _checkPop, _cleanupOldHistory (+47 more)

### Community 6 - "Community 6"
Cohesion: 0.04
Nodes (46): ../../auth/providers/auth_provider.dart, FitPointsService, _AbuseCheckResult, Challenge, ChallengeCreateResult, ChallengePayout, ChallengeService, _checkOpponentAbuse (+38 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (44): AuthNotifier, AuthService, build, _checkMigration, _invalidateUserData, _invalidateUserProviders, IsGuestNotifier, PendingMigrationNotifier (+36 more)

### Community 8 - "Community 8"
Cohesion: 0.04
Nodes (41): AuthResult, AuthService, _clearLocalStorage, _ensureUserDoc, _mapError, signOut, AuthSessionCleanupService, AiUsageService (+33 more)

### Community 9 - "Community 9"
Cohesion: 0.05
Nodes (40): _addCylinder, Align, AnimatedContainer, build, Column, Container, CustomPaint, cycle (+32 more)

### Community 10 - "Community 10"
Cohesion: 0.05
Nodes (38): ../../../core/widgets/oil_level_selector.dart, build, Column, Container, _DetailRing, FoodDetailsScreen, _FoodDetailsScreenState, initState (+30 more)

### Community 11 - "Community 11"
Cohesion: 0.05
Nodes (36): _AccountCard, _activityLabel, _appUseLabel, BorderSide, build, _capitalize, Center, Column (+28 more)

### Community 12 - "Community 12"
Cohesion: 0.06
Nodes (33): _ActionIcon, add, build, Center, CircularPercentIndicator, Column, _DateNavBtn, _DismissedMealsNotifier (+25 more)

### Community 13 - "Community 13"
Cohesion: 0.06
Nodes (35): _addFromSearch, _adjust, build, _CircleBtn, Column, _confirm, Container, CustomMealFormScreen (+27 more)

### Community 14 - "Community 14"
Cohesion: 0.06
Nodes (32): AppShell, _AppShellState, build, GestureDetector, _NavItem, Scaffold, SizedBox, build (+24 more)

### Community 15 - "Community 15"
Cohesion: 0.06
Nodes (30): ../../../core/widgets/goal_pace_slider.dart, _back, build, _canProceed, dispose, Expanded, _GenderChip, GestureDetector (+22 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (29): build, Column, dispose, GestureDetector, GoalPaceSlider, _GoalPaceSliderState, initState, _ProjRow (+21 more)

### Community 17 - "Community 17"
Cohesion: 0.11
Nodes (19): RegisterPlugins(), FlutterWindow(), OnCreate(), Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle() (+11 more)

### Community 18 - "Community 18"
Cohesion: 0.07
Nodes (28): _BigStat, build, Center, Column, Container, _DetailedStats, Divider, _empty (+20 more)

### Community 19 - "Community 19"
Cohesion: 0.08
Nodes (24): build, Column, _ComingSoonTile, Container, _divider, _fmt, _GroupLabel, _HealthConnectCard (+16 more)

### Community 20 - "Community 20"
Cohesion: 0.08
Nodes (25): _AdjustChip, build, Column, Container, DayMacros, Expanded, _FitPointsCard, _fmt (+17 more)

### Community 21 - "Community 21"
Cohesion: 0.1
Nodes (19): AppShell, AuthGate, build, FitMeApp, LoginScreen, main, MaterialApp, OnboardingScreen (+11 more)

### Community 22 - "Community 22"
Cohesion: 0.11
Nodes (16): custom_meal_ingredient.dart, CustomMealIngredient, scaledTo, copyWith, dateFor, FoodItem, scaleToAmount, _today (+8 more)

### Community 23 - "Community 23"
Cohesion: 0.14
Nodes (4): fl_register_plugins(), main(), my_application_activate(), my_application_new()

### Community 24 - "Community 24"
Cohesion: 0.29
Nodes (2): FlutterAppDelegate, AppDelegate

### Community 25 - "Community 25"
Cohesion: 0.29
Nodes (6): buildNextSet, copyWith, _defaultRestSeconds, Exercise, ExerciseSet, withUpdatedPR

### Community 26 - "Community 26"
Cohesion: 0.29
Nodes (6): copyWith, fromOnboarding, paceDelta, paceLabel, UserProfile, weeklyChangeKg

### Community 27 - "Community 27"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), NSWindow, MainFlutterWindow

### Community 28 - "Community 28"
Cohesion: 0.47
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 29 - "Community 29"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 30 - "Community 30"
Cohesion: 0.4
Nodes (4): copyWith, _today, Workout, exercise.dart

### Community 31 - "Community 31"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 32 - "Community 32"
Cohesion: 0.67
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 33 - "Community 33"
Cohesion: 0.67
Nodes (2): main, package:flutter_test/flutter_test.dart

### Community 34 - "Community 34"
Cohesion: 1.0
Nodes (1): MainActivity

## Knowledge Gaps
- **862 isolated node(s):** `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `DefaultFirebaseOptions`, `UnsupportedError` (+857 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 24`** (7 nodes): `FlutterAppDelegate`, `AppDelegate.swift`, `AppDelegate.swift`, `AppDelegate`, `.application()`, `.applicationShouldTerminateAfterLastWindowClosed()`, `.applicationSupportsSecureRestorableState()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (5 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (3 nodes): `GeneratedPluginRegistrant.m`, `GeneratedPluginRegistrant`, `-registerWithRegistry`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (3 nodes): `main`, `package:flutter_test/flutter_test.dart`, `widget_test.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 7` to `Community 0`, `Community 1`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 18`, `Community 19`, `Community 20`, `Community 21`?**
  _High betweenness centrality (0.166) - this node is a cross-community bridge._
- **Why does `package:flutter/material.dart` connect `Community 0` to `Community 1`, `Community 3`, `Community 4`, `Community 5`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 18`, `Community 19`, `Community 20`, `Community 21`?**
  _High betweenness centrality (0.158) - this node is a cross-community bridge._
- **Why does `../../../core/theme/app_theme.dart` connect `Community 0` to `Community 1`, `Community 3`, `Community 4`, `Community 5`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 18`, `Community 19`, `Community 20`, `Community 21`?**
  _High betweenness centrality (0.125) - this node is a cross-community bridge._
- **What connects `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry` to the rest of the system?**
  _862 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._