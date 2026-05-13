# FitMe: Incomplete & Broken Features

This document tracks features that are currently non-functional, partially implemented, or in the process of being refactored/removed.

## 2. Workout Tracking (Missing UI)
- **Status**: Backend-only.
- **Problem**: The `WorkoutRepository` and exercise models are well-defined, but there are **no screens** in the app to actually log or view workouts.
- **User Note**: This section will be built later.
- **Missing**: 
    - Active workout session UI.
    - Exercise library and search screens.
    - Historical volume/workout charts.

## 3. FitMe Wrapped (No Sharing)
- **Status**: UI-only.
- **Problem**: The "Wrapped" recap screen is visually complete, but the share button is a no-op.
- **User Note**: This will appear every 6 months (similar to Spotify Wrapped frequency).
- **Missing**: `share_plus` package integration to capture and share image bytes.

## 4. Data Backup (Incomplete)
- **Status**: Partially Functional.
- **Problem**: `BackupService` backs up logs and streaks, but several data types are ignored.
- **Missing**:
    - **Recipe Favorites**: Currently a `TODO` placeholder; favorites are stored in `SharedPreferences` and not synced to Firestore.
    - **Custom Recipes**: Full recipe definitions are not included in the main backup bundle.

## 5. AI Usage & Smart Logger Enforcement
- **Status**: Mock Logic / Inconsistent.
- **Problem**: `incrementSmartLoggerCount` tracks voice/text usage, while `AiUsageService` tracks Insights usage. They are currently not unified.
- **Bug**: Usage counts do not update/decrement correctly across different AI features (e.g., using AI Diet Analysis doesn't seem to impact the "Smart Logger" usage quota).
- **Missing**: 
    - Unified AI quota system.
    - UI logic to block users or prompt for premium once they reach the daily limit.

## 6. Social Features
- **Status**: Not Started.
- **Problem**: No infrastructure for friend lists, community leaderboards, or social data sharing.

## 7. Gemini & AI Tools
- **Status**: Unstable.
- **Problem**: The Diet Plan Maker and Diet Analysis tools fail intermittently (often due to invalid model identifiers or API timeouts).
- **Action**: Fixed the model identifiers (changed `gemini-2.5-flash` to `gemini-1.5-flash/pro`) to restore functionality.

---
### Recently Fixed / Integrated
- [x] **Weekly Rebalancer**: Logic hooked into startup flow and Insights dashboard implemented. (±20% safety cap verified).
- [x] **Adherence Engine**: Concrete "Adherence Completion" rules and "Quality Modifiers" implemented in `ConsistencyEngine` using dynamic targets.
