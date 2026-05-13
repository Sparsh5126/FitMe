# FitMe: Application Flow & Screen Architecture

This document outlines the user journey and the structural flow of the FitMe application, from initial launch to daily usage.

## 1. Authentication & Entry Flow
- **Splash Screen**: Initial loading and Firebase initialization.
- **Auth Gate**: Determines user state:
    - **Not Authenticated**: Directed to **Login/Signup Screen**.
    - **Guest Mode**: Direct entry to AppShell (Local storage).
    - **Authenticated**: Proceeds to Profile Gate.
- **Profile Gate**: Checks for completed onboarding:
    - **Incomplete Profile**: Forced transition to **Onboarding Screen**.
    - **Complete Profile**: Entry to **App Shell**.

## 2. Onboarding Journey
- **User Attributes**: Collection of Age, Gender, Height, and Weight.
- **Goal Setting**: Defining target weight and activity levels.
- **Migration/Sync**: Initial data setup and permission requests (Health Connect).

## 3. The App Shell (Main Navigation)
The app uses a persistent bottom navigation bar with five primary touchpoints:

### A. Menu (Index 0)
- **Menu Screen**: Access to Backup/Restore, Notifications settings, App Info, and Logout.

### B. Insights (Index 1)
- **Insights Screen**: Dashboard for progress charts (Weight, Calories).
- **Navigation from here**:
    - Tap "Diet Analysis" -> **Diet Analysis Screen**.
    - Tap "Diet Plan" -> **Diet Plan Screen**.
    - Tap "Streak Card" -> **Streak Screen**.

### C. Home / Nutrition (Index 2 - Default)
- **Home Screen**: Current day's calorie/macro progress and log history.
- **Navigation from here**:
    - Tap Macro Card -> **Macro Detail Screen**.
    - Tap Logged Item -> **Food Details Screen**.
    - **Central Log (+)**:
        - If on Home: Opens **Log Sheet** (Manual search/logging).
        - If elsewhere: Switches to Home tab.

### D. Smart Logger (Index 3 - Modal)
- **Smart Logger Sheet**: An overlay that accepts text or voice input to parse meals using AI.
- **Navigation from here**: Success triggers a refresh of the Home Screen data.

### E. Profile (Index 4)
- **Profile Screen**: Viewing and editing personal metrics, goals, and account details.

## 4. Common User Flows

### Logging Food (Manual)
1. **Home Screen** -> Tap **(+)**.
2. **Log Sheet** opens -> Search for food or select from **Favorites**.
3. Select item -> **Food Details Screen**.
4. Adjust portions -> **Quantity Selection Screen**.
5. Confirm -> Item added to Home Screen log.

### Logging Food (AI)
1. Tap **Smart Logger** icon in Nav Bar.
2. Type meal description (e.g., "Lunch: Chicken salad and water").
3. Submit -> AI processes and automatically adds items to the daily log.

### Reviewing Consistency
1. **Insights Screen** -> View Momentum/Streak summary.
2. Tap Card -> **Streak Screen** for detailed calendar view and tier breakdown.
3. Periodic triggers -> **Wrapped Screen** displays a full-screen recap of achievements.

### Recipe Management
1. **Menu** -> **Recipes**.
2. **Recipes Screen** -> List of saved custom meals.
3. Tap Recipe -> **Recipe Detail Screen** (Edit ingredients/macro distribution).
