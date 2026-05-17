# FitMe Theme JSON Generator Prompt

Copy and paste the text below to any AI model (like ChatGPT, Claude, or Gemini) to generate a new JSON theme that can be pasted directly into FitMe!

---
**COPY FROM HERE DOWN:**
---

Act as an expert UI/UX designer. I want you to create a new color theme for my fitness app "FitMe" and output it strictly as a JSON object.

### Rules for the Theme Colors:
1. "backgroundPrimary" should be the darkest color. "backgroundSecondary" slightly lighter.
2. "surfacePrimary" -> "surfaceSecondary" -> "surfaceElevated" get progressively lighter to show depth.
3. "accent" is the primary interactive brand color. Provide a lighter version ("accentLight", typically hex + low opacity like 0x26...) and a darker version ("accentDark").
4. "proteinColor", "carbsColor", "fatsColor", "waterColor", and "caloriesColor" are used for nutrition progress rings. Ensure they are vibrant and harmonious.
5. Provide color values as Strings in standard Flutter hex format: `"0xFF[HEX]"`. For example, `"0xFFFF9500"`.

### JSON Format
Generate ONLY a raw JSON string using the following structure. Replace all the placeholder string values with your generated colors!

```json
{
  "id": "fitme-[theme-name]",
  "name": "FitMe [Theme Name]",
  "description": "[Short description]",
  "version": "1.0.0",
  "colors": {
    "backgroundPrimary": "0xFF0D0D0D",
    "backgroundSecondary": "0xFF1A1A1A",
    "surfacePrimary": "0xFF1A1A1A",
    "surfaceSecondary": "0xFF242424",
    "surfaceElevated": "0xFF2E2E2E",
    "surfaceBorder": "0xFF242424",
    "textPrimary": "0xFFFFFFFF",
    "textSecondary": "0xFF888888",
    "textAccent": "0xFFFF9500",
    "textDisabled": "0xFF555555",
    "accent": "0xFFFF9500",
    "accentLight": "0x26FF9500",
    "accentDark": "0xFFD97600",
    "success": "0xFF00E5A0",
    "warning": "0xFFFF9500",
    "error": "0xFFFF453A",
    "info": "0xFF00C7FF",
    "proteinColor": "0xFF4D9FFF",
    "carbsColor": "0xFFFF9500",
    "fatsColor": "0xFFAF52DE",
    "waterColor": "0xFF00C7FF",
    "caloriesColor": "0xFFFF9500",
    "disabled": "0xFF444444",
    "overlay": "0x80000000"
  }
}
```

Please generate a **[INSERT THEME CONCEPT HERE, e.g. "Cyberpunk"]** theme now!
