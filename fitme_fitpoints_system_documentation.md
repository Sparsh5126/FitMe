# FitMe FitPoints System Documentation

# Overview

FitPoints is FitMe’s long-term consistency and accountability system.

The goal of FitPoints is NOT to turn FitMe into a game.

Instead, FitPoints exists to:
- reward consistency
- encourage healthy habits
- build accountability
- motivate long-term adherence
- create meaningful progression
- support social challenges later

FitPoints are intentionally:
- scarce
- valuable
- difficult to exploit
- tied to discipline rather than spam activity

---

# Core Philosophy

FitMe should feel like:
- a serious health platform
- a fitness accountability ecosystem
- an intelligent nutrition/workout assistant

NOT:
- a childish XP farming app
- a casino-style dopamine loop
- an arcade progression system

FitPoints reward:
- consistency
- adherence
- effort
- quality logging
- long-term progress

NOT:
- starvation
- overtraining
- spam actions
- fake activity

---

# Core Formula

FitPoints Earned =
Base Action Points × Consistency Tier Multiplier × Quality Modifier

---

# Base Action Points

Points are intentionally small.

Most actions reward:
- 1–2 FitPoints before multipliers.

This avoids inflated meaningless numbers.

---

# Nutrition Actions

| Action | Base FP |
|---|---|
| Log meal | 1 |
| Complete daily logging | 2 |
| Hit protein goal | 1 |
| Hit calorie target range | 1 |
| Hit macro adherence | 1 |
| Complete hydration goal | 1 |

---

# Complete Daily Logging

FitMe does NOT force:
- breakfast
- lunch
- dinner

Instead:
Complete logging means:
- Meaningful nutrition logging (calories + sufficient logs)
- Meaningful workout activity (completed workout sessions)
- Activity validation (anti-spam)

A day is marked "active" if ANY of the above criteria are met.

The system intelligently checks:
- food uniqueness
- calorie contribution
- logging quality
- realistic meal behavior

This supports users who:
- bulk log at night
- intermittent fast
- snack frequently
- eat irregular schedules

---

# Fitness Actions

| Action | Base FP |
|---|---|
| Complete 3 exercises | 1 |
| Complete workout | 2 |
| Hit step goal | 1 |
| Complete active recovery day | 1 |
| Create custom workout plan | 2 |
| Follow generated workout plan | 2 |
| Complete workout plan analysis | 2 |
| Share workout plan with friend | 2 per friend |
| Share app on social (monthly cap: once/month) | 10 |

---

# Planning & Intelligence Actions

| Action | Base FP |
|---|---|
| Create useful custom meal | 1 |
| Create recipe | 2 |
| Complete diet analysis | 2 |
| Follow generated diet plan for full day | 2 |

---

# ConsistencyTier (Efficiency Multipliers)
Used in Insights and popups to indicate point-earning efficiency.

| Tier | Name | Multiplier |
|---|---|---|
| 0 | Bronze Efficiency | 1.0x |
| 1 | Silver Efficiency | 1.5x |
| 2 | Gold Efficiency | 2.0x |
| 3 | Platinum Efficiency | 3.0x |
| 4 | Diamond Efficiency | 5.0x |
| 5 | Diamond Efficiency | 5.0x |

---

# StreakTier (Visible Progression)
Used on the Streak Page with weight-themed nomenclature.

| Level | Name | Duration |
|---|---|---|
| 0 | Light Dumbbell | 0–7 days |
| 1 | Heavy Dumbbell | 8–21 days |
| 2 | Barbell | 22–44 days |
| 3 | 1 Plate Barbell | 45–89 days |
| 4 | 2 Plate Barbell | 90–149 days |
| 5 | 4 Plate Barbell | 150+ days |

---

# Momentum System

Momentum represents:
- recent consistency
- adherence trend
- activity continuity

Range:
0–100

Momentum:
- increases gradually
- decays slowly
- protects users from full collapse after one missed day

A high-tier user missing one day:
- loses some momentum
- weakens slightly
- but does NOT instantly collapse to the lowest tier

---

# Quality Modifier

| Quality | Modifier |
|---|---|
| Poor | 0.5x |
| Normal | 1x |
| High Quality | 1.25x |

High-quality logging includes:
- realistic meals
- proper calorie coverage
- consistent protein tracking
- healthy adherence
- meaningful logging

Low-quality logging includes:
- spam logs
- fake logs
- tiny meaningless entries
- exploit behavior

---

# Anti-Abuse System

FitPoints must remain difficult to farm.

FitMe avoids harsh cooldowns because users may:
- eat the same meals multiple times/day
- bulk log meals at night

Instead, FitMe uses:
- intelligent duplicate detection
- similarity scoring
- activity validation

---

# Duplicate Detection Logic

Examples:
- first log of meal → full FP
- second realistic repeat → full FP
- repeated spam logs → reduced/no FP

Detection checks:
- ingredient similarity
- calorie similarity
- meal structure
- quantities
- timestamps

NOT only meal names.

---

# Daily Point Caps

Recommended:
15–25 meaningful FP/day before multipliers.

With high multipliers:
75–125/day maximum.

This prevents:
- infinite grinding
- spam farming
- inflated economies

---

# Challenge System

FitMe challenges focus on:
- accountability
- long-term goals
- healthy competition

NOT arcade mini-games.

---

# Challenge Stakes

Users can stake FitPoints against each other.

Example:
10 FP + 10 FP stake
+
5 FP FitMe bonus
=
25 FP total reward

---

# Goal-Based Challenges

Primary challenge type:
Goal Weight Challenges

Example:

User A:
52kg → 60kg

User B:
78kg → 72kg

Challenge duration:
- 30 days
- 60 days
- 90 days

---

# Challenge Scoring

Challenges are NOT based on:
- fastest weight loss
- extreme behavior

Instead scoring uses:
- Goal Completion %
- Consistency
- Adherence

This keeps:
- bulking
- cutting
- recomposition
fair and healthy.

---

# Accountability Challenges

FitMe also supports cooperative challenges.

Examples:
- complete 30 workouts
- maintain protein adherence
- maintain logging streaks
- hydration consistency

If BOTH users succeed:
- both receive rewards

This encourages:
- teamwork
- accountability
- healthy motivation

instead of toxic competition.

---

# Guest Mode Support

Guest users can:
- earn FitPoints locally
- build streaks
- maintain momentum

But:
- social challenges
- synced leaderboards
- multiplayer systems

require login.

---

# UI Philosophy

FitPoints UI should feel:
- subtle
- premium
- fitness-focused

FitMe intentionally avoids:
- excessive confetti
- childish game aesthetics
- battle-pass mechanics
- casino-like reward spam

The system should feel:
- disciplined
- respected
- earned

---

# Architecture

## FitPointsService
Responsible for:
- point calculations
- multipliers
- quality modifiers
- caps
- duplicate detection

---

## ConsistencyEngine
Responsible for:
- streak calculations
- active-day detection
- adherence scoring
- consistency metrics

---

## MomentumService
Responsible for:
- momentum decay
- momentum recovery
- tier protection

---

## ChallengeService
Responsible for:
- challenge lifecycle
- scoring
- stakes
- rewards
- anti-abuse

---

# ConsistencySnapshot

Single source of truth used across:
- Streak screen
- Insights screen
- Home widgets
- FitPoints systems

Contains:
- current streak
- longest streak
- momentum
- active days
- FitPoints
- progression level
- consistency tier

This prevents:
- stale data
- duplicate calculations
- screen mismatches

---

# Final Product Goal

FitPoints should:
- encourage healthy consistency
- reward long-term discipline
- create emotional investment
- support accountability
- support meaningful competition
- remain difficult to exploit

FitMe should feel like:
- a serious fitness ecosystem
with meaningful progression,
NOT a cheap gamified XP app.
