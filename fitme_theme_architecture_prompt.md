# FitMe Theme Architecture & Multi-Theme System Prompt

# Goal

Implement a fully scalable multi-theme architecture across the entire FitMe app so future generated theme packs can be added easily without refactoring the UI again.

The app should support:
- multiple predefined themes
- downloadable/generated theme packs later
- easy theme switching from settings
- runtime theme changes
- centralized styling
- future Gemini-generated theme files

Users will NOT create themes manually.

Instead:
- future theme files will be generated externally
- app should load/use those themes cleanly

The app must be architected now to support this properly.

---

# 1. Centralize ALL Styling

Remove ALL hardcoded:
- colors
- text styles
- spacing
- radius
- elevations
- gradients

DO NOT use:
- Colors.black
- Colors.white
- Color(0xFF...)

directly inside widgets/screens/components.

Everything must come from centralized theme configuration.

---

# 2. Use Semantic Theme Tokens

DO NOT define themes using literal color names.

BAD:
- bluePrimary
- greenCard
- darkGrey

GOOD:
- backgroundPrimary
- backgroundSecondary
- surfacePrimary
- surfaceElevated
- textPrimary
- textSecondary
- accent
- success
- warning
- error
- cardBorder

This allows completely different future themes without changing UI code.

---

# 3. Create Theme File Architecture

Implement support for external structured theme files.

Example structure:

ThemeConfig {
  id,
  name,
  colors,
  typography,
  spacing,
  radius,
  gradients,
  chartStyles,
  animations,
}

The app should be able to:
- load theme configs
- register multiple themes
- switch themes dynamically
- persist selected theme

Future Gemini-generated themes should plug into this system easily.

---

# 4. IMPORTANT: Create Initial Theme File Using Current App Colors

Generate a FULL theme file using the app’s CURRENT styling/colors as the base reference theme.

This file will become:
- the master theme schema
- the template format for future Gemini-generated themes

Requirements:
- include ALL supported theme fields
- include ALL semantic color tokens
- include typography
- spacing
- radius
- gradients
- chart styles
- animation settings
- component styles

The file should represent the CURRENT FitMe look exactly.

Example:
- fitme_default_theme.dart
OR
- fitme_default_theme.json

depending on chosen architecture.

---

# 5. Make Theme Schema Strict & Consistent

Future Gemini-generated themes MUST follow the EXACT SAME structure.

Design the schema so:
- missing fields fail safely
- theme validation exists
- defaults can be applied
- app never crashes from incomplete themes

Add:
- schema validation
- fallback handling
- compatibility versioning if needed

---

# 6. Prepare Gemini-Compatible Theme Generation

The generated base theme file should be:
- clean
- readable
- structured
- self-explanatory

So later it can be sent directly to Gemini with prompts like:
“Generate a cyberpunk AMOLED theme using this exact schema.”

Generated themes should plug into the app without requiring code changes.

---

# 7. Create Central Theme Manager

Implement centralized:
- ThemeManager
- ThemeController
- ThemeProvider

Responsible for:
- active theme state
- loading theme files
- switching themes
- notifying UI
- persistence
- startup restoration

---

# 8. Settings Theme Selector

Add architecture for:
- theme selection screen in settings
- theme preview cards
- instant runtime switching
- selected theme persistence

Users should:
- open settings
- select theme
- app updates instantly

---

# 9. Make Entire App Theme-Aware

Audit ALL UI:
- Home
- Smart Logger
- Insights
- Streaks
- FitPoints
- Auth screens
- Settings
- Graphs
- Bottom sheets
- Dialogs
- Navigation
- Buttons
- Inputs
- Chips
- Cards

Everything must use theme tokens only.

No hardcoded styling.

---

# 10. Standardize Typography

Create centralized typography system.

DO NOT hardcode:
- font sizes
- weights
- colors

Use:
- ThemeTypography
- AppTextStyles

Typography should come from theme config.

---

# 11. Standardize Layout Styling

Centralize:
- spacing scale
- border radius
- shadows/elevations
- animation timings

Examples:
- AppSpacing.md
- AppRadius.lg
- AppElevation.card

Avoid random values throughout codebase.

---

# 12. Theme-Compatible Graphs & Charts

Refactor graphs/charts to support:
- dynamic colors
- gradients
- adaptive tooltips
- adaptive labels
- adaptive grid lines

Charts must automatically adapt to all future themes.

---

# 13. Smart Logger Theme Compatibility

Refactor ALL Smart Logger UI to be theme-driven:
- AI cards
- chat bubbles
- command pills
- lock cards
- barcode scanner
- suggestions
- sheets/dialogs

---

# 14. Reusable Themed Components

Create reusable components:
- AppCard
- AppButton
- AppTextField
- AppDialog
- AppBottomSheet
- AppScaffold

These components should automatically adapt to current theme.

---

# 15. Remove Style Duplication

Audit and remove:
- duplicate card styles
- repeated shadows
- repeated gradients
- repeated text styles
- repeated paddings/margins

Centralize styling completely.

---

# 16. Theme Persistence

Persist selected theme:
- locally
- across app restarts
- across login/logout

Future-proof for:
- cloud theme sync later

---

# 17. Future Theme Pack Support

Architecture should support:
- adding new theme files later
- importing generated theme configs
- enabling/disabling themes
- theme versioning if needed

The app should NOT require code rewrites for new themes.

---

# 18. Accessibility & Contrast Safety

Ensure theme architecture supports:
- readable text contrast
- accessibility scaling
- dark/light readability
- AMOLED support
- color-safe combinations

Avoid themes breaking usability.

---

# 19. Cleanup Requirements

Audit and remove:
- inline styling
- hardcoded colors
- duplicated theme logic
- inconsistent spacing/radius
- widget-specific styling systems

---

# 20. Deliverables

Provide:
- centralized theme architecture
- reusable themed components
- migrated screens/widgets
- theme manager system
- settings theme selector
- generated base theme file using current app colors
- Gemini-compatible theme schema/template
- future theme integration guide
- summary of removed hardcoded styling

---

# 21. Final Goal

FitMe should become:
- fully theme-ready
- easy to restyle later
- scalable for future generated theme packs
- visually consistent
- premium-looking

without needing another massive UI refactor later.
