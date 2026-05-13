# FitMe Codebase Optimization & Cleanup Prompt

## Goal

Perform a deep optimization and cleanup of the entire FitMe codebase without breaking functionality.

Main goals:
- reduce technical debt
- improve maintainability
- improve performance
- remove duplicate logic
- simplify architecture
- remove dead/useless code
- standardize systems
- improve app responsiveness

DO NOT rewrite the whole app unnecessarily.
Refactor intelligently and safely.

---

# 1. Remove Dead / Unused Code

Find and remove:
- unused functions
- unused classes
- unused widgets
- unused services
- unused providers
- unused models
- unused utilities/helpers
- unused imports
- unused variables/constants
- unreachable code
- deprecated experimental code
- commented-out old implementations
- duplicate feature attempts

Audit the entire project for:
- files no longer referenced
- abandoned systems
- legacy integrations
- old auth logic
- old streak logic
- old FitPoints logic
- duplicate Smart Logger logic

DO NOT remove anything actively used.

---

# 2. Remove Duplicate Logic

Consolidate:
- streak calculations
- consistency calculations
- FitPoints calculations
- nutrition aggregation
- auth/session handling
- Smart Logger parsing
- search ranking
- duplicate validation
- cache clearing
- guest/auth switching
- date formatting
- API handling
- navigation guards

Create centralized services/utilities instead of repeated implementations.

Examples:
- ConsistencyEngine
- AuthSessionManager
- FoodKnowledgeResolver
- InsightsAggregationService

There should be ONE source of truth for shared systems.

---

# 3. Remove Excessive/Low-Value Comments

Remove:
- obvious comments
- noisy comments
- outdated comments
- redundant inline explanations
- commented-out code blocks
- debug comments
- AI-generated filler comments

Keep only:
- architecture explanations
- complex algorithm explanations
- important warnings
- non-obvious business logic

---

# 4. Optimize Widget Rebuilds

Audit Flutter UI for:
- unnecessary rebuilds
- large widget trees rebuilding entirely
- improper provider watching
- expensive UI calculations in build()
- repeated FutureBuilder usage
- nested rebuild chains

Optimize using:
- const widgets
- selector patterns
- memoization
- proper provider separation
- extracted widgets
- lazy loading

---

# 5. Optimize State Management

Audit:
- Riverpod/providers/blocs
- provider nesting
- stale providers
- unnecessary global state
- duplicated state
- auth hydration issues
- cache invalidation issues

Fix:
- stale listeners
- duplicate providers
- memory leaks
- invalid rebuild cycles
- inconsistent auth state propagation

---

# 6. Optimize Smart Logger Architecture

Current Smart Logger likely has:
- duplicated search logic
- duplicated parsing logic
- duplicated ranking systems
- multiple fallback implementations

Centralize into:
- FoodKnowledgeResolver
- SmartLoggerEngine
- SearchRankingEngine

Use one pipeline only.

---

# 7. Optimize Database & Cache Usage

Audit:
- Hive/SQLite usage
- duplicate writes
- unnecessary reads
- stale cache persistence
- repeated aggregation recalculations

Optimize:
- indexing
- caching strategy
- aggregation rebuild timing
- background computation
- async batching

Avoid:
- recalculating entire insights repeatedly
- rebuilding graphs unnecessarily
- duplicate writes on logging

---

# 8. Remove Legacy Auth/Guest Logic

Consolidate:
- login flow
- logout cleanup
- guest migration
- auth hydration
- session restoration
- cache clearing

Implement centralized:
- AuthSessionCleanupService

---

# 9. Improve Project Structure

Suggested structure:

core/
features/
services/
models/
repositories/
providers/
widgets/
utils/

Separate:
- business logic
- UI
- data layer
- services
- state management

Avoid giant files.

---

# 10. Reduce File Complexity

Split overly large files:
- huge screens
- giant services
- oversized providers
- multi-purpose widgets

Target:
- single responsibility
- modularity
- reusable components

---

# 11. Performance Optimization

Audit:
- app startup
- auth restore
- insights loading
- Smart Logger responsiveness
- graph rendering
- navigation transitions

Optimize:
- async loading
- lazy initialization
- expensive computations
- blocking UI thread work

Move heavy work off UI thread where possible.

---

# 12. Logging Cleanup

Remove:
- spammy debug logs
- duplicated logs
- noisy prints

Keep:
- structured important logs
- auth events
- analytics rebuilds
- error reporting
- crash diagnostics

Use consistent logging format:
- [Auth]
- [Insights]
- [SmartLogger]
- [FitPoints]

---

# 13. Dependency Cleanup

Audit pubspec dependencies.

Remove:
- unused packages
- duplicate libraries
- abandoned packages
- conflicting integrations
- legacy health integrations

Update:
- outdated packages
- incompatible plugins
- Android/iOS compatibility issues

Especially audit:
- health plugins
- permission plugins
- auth plugins
- AI/networking packages

---

# 14. Code Quality Improvements

Apply:
- lint cleanup
- analyzer fixes
- null safety cleanup
- consistent naming
- consistent async handling
- error handling standardization

Fix:
- unsafe null assertions
- unnecessary dynamic usage
- inconsistent typing
- nested callback chains

---

# 15. Final Verification Requirements

After optimization:
- app behavior must remain identical or improved
- no feature regressions
- no broken navigation
- no auth regressions
- no stale state bugs
- no Smart Logger regressions

Run:
flutter analyze
flutter test

Ensure:
- no analyzer errors
- no major warnings
- improved performance
- smaller cleaner codebase
- easier maintainability

---

# 16. Deliverables

Provide:
- summary of removed code
- summary of consolidated systems
- list of major architecture improvements
- performance improvements made
- files cleaned/refactored
- duplicate systems removed
- dependency cleanup summary

Goal:
Transform the FitMe codebase into a cleaner, faster, more maintainable production-grade architecture without changing the app’s core experience.
