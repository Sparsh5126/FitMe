# FitMe App - Critical Fixes & Smart Logger Redesign

# 1. Streak / Insights Day Count Logic Bug

## Current issue
The streak count is inconsistent between:
- Insights page
- Streak page

Example:
- Main streak number shows `1`
- But streak blocks/history clearly show `2 days`

This means:
- streak calculation logic
- displayed streak value
- or sync/update timing
is inconsistent across screens.

## Required fix
Unify streak calculation across:
- Insights page
- Streak page
- Home page widgets/cards
- Any streak-dependent UI

There should be ONE shared streak calculation source/service.

### Expected behavior
If streak blocks/history indicate 2 valid days:
- top streak count must also show 2 everywhere.

---

# 2. Past Date Logging Should Affect Streaks & Insights

## Current issue
Logging food for previous dates:
- does NOT update streaks
- does NOT update insights correctly

Example:
- User logs meals for yesterday
- streak remains unchanged
- insights charts/cards do not refresh properly

## Required behavior
When user logs/edit meals for past dates:
- recompute streak history
- recompute insights aggregates
- refresh charts/cards immediately
- update weekly/monthly adherence correctly

### Recalculate:
- streaks
- longest streak
- weekly consistency
- monthly consistency
- calorie/macros history
- insights graphs
- progress summaries

---

# 3. Smart Logger Search Bar Missing Barcode Scanner

## Current issue
Normal search bar has barcode scanner.
Smart Logger search bar does not.

## Required fix
Add barcode scanner button to Smart Logger search bar with same functionality as normal search.

### Requirements
- identical scanning flow
- same scanner UI
- same product lookup logic
- same fallback behavior
- same permissions handling

Do NOT maintain separate barcode implementations.

---

# 4. Google Fit Integration Errors

## Current issue
Google Fit connection is failing.
Current integrations screen shows:
“Could not connect to Health.”

Also:
- Apple Health is shown even though app is Android-first.

## Required fixes

### A. Remove Apple Health temporarily
Since app is Android-focused:
- remove Apple Health references/UI for now
- remove “Apple Health / Google Fit” combined label
- show only Google Fit / Health Connect

### B. Fix Google Fit / Health Connect integration
Audit:
- permissions
- OAuth flow
- Health Connect availability checks
- package detection
- API auth
- async loading states
- error handling

### Required behavior
- Connect button should work reliably
- Proper permission prompts
- Proper loading/error states
- Detect missing Health Connect app cleanly
- Open install/settings page if needed

### Improve error handling
Do NOT show vague:
“Could not connect to Health.”

Instead show:
- permission denied
- Health Connect not installed
- Google account issue
- API unavailable
- sync unavailable

---

# 5. Guest Mode Navigation/UI Broken

## Current issues
In guest mode:
- Home page is blank/not visible
- Profile page is blank/not visible
- only bottom navigation bar appears

Also:
- Settings page infinitely loads and never opens

## Required fix
Guest mode should still allow:
- Home page
- Profile page
- Settings page
- tracking pages
- local progress/history
- Smart Logger basic usage

### Audit:
- guest auth guards
- route protection
- null user assumptions
- provider initialization
- async auth loading states
- navigation gating logic

### Required behavior
Guest mode should feel fully usable except restricted features.

---

# 6. Sign In / Create Account Buttons Not Working

## Current issue
Buttons:
- Sign In
- Create Account
do nothing or fail to navigate.

## Required fix
Audit:
- navigation routes
- auth modal/screen
- provider setup
- navigator keys
- auth state listeners
- guest→auth transitions

### Required behavior
Buttons must:
- open auth screen immediately
- support both login and signup flows
- work from every entry point

---

# 7. Smart Logger “Sign Up Free” CTA Broken

## Current issue
In guest mode:
- tapping “Sign Up Free” in Smart Logger does not correctly open auth flow.

## Required behavior
When guest taps:
- “Sign Up Free”
- AI lock CTA
- AI fallback login prompt

It should:
- directly open Login/Signup screen
- preserve Smart Logger state/input
- return user back after auth if possible

---

# 8. Stale Insights Data From Previous Login

## Current issue
After logout:
- most account data clears correctly
- BUT insights graphs still show old account data from previous login

This is a major stale cache/session issue.

## Required fix
On logout:
- clear ALL account-specific insights caches
- clear analytics cache
- clear graph datasets
- clear provider state
- clear persisted aggregates

### Audit:
- Hive/SQLite/shared prefs caches
- provider state
- memoized graph data
- analytics repositories
- stale auth-bound listeners

### Required behavior
After logout:
- guest mode starts with clean local guest insights
- no previous account graphs remain
- no stale charts/history visible

---

# 9. Required Architecture Fixes

## Centralize streak + insights recalculation
Create shared services:
- `StreakService`
- `InsightsAggregationService`

Avoid separate calculations per screen.

---

## Centralize auth/session clearing
Create:
- `AuthSessionCleanupService`

Responsible for:
- auth state reset
- provider disposal
- cache clearing
- insights reset
- graph reset
- navigation reset

---

# 10. Required Debugging

Add logs for:
- streak recalculation
- past-date log updates
- insights aggregation refresh
- auth state changes
- logout cleanup
- guest route gating
- Smart Logger auth CTA
- Google Fit connection flow
- provider initialization failures
- stale cache detection

---

# 11. Expected Final Behavior

- Streak counts match everywhere.
- Logging past meals updates streaks/insights correctly.
- Smart Logger has barcode scanner parity with normal search.
- Google Fit works correctly on Android.
- Apple Health removed temporarily.
- Guest mode pages work properly.
- Settings page opens normally.
- Login/signup buttons work everywhere.
- Smart Logger signup CTA opens auth flow correctly.
- Logout fully clears previous user insights/graphs/cached analytics.
- Guest mode starts clean without stale account data.
