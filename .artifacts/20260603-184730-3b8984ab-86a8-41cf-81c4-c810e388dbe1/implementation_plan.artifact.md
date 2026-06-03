# Implementation Plan - AI-Driven Recipe Sales Machine

Transform the app into a proactive monetization engine by adding generation triggers at every intent point.

## User Review Required

- **Search Behavior**: If a user searches and clicks "Enter", and there are no direct matches, should we **automatically** start generating a recipe or just **suggest** it? (I recommend suggesting first with a big "Magic" button).
- **Home Screen "Surprise"**: This widget will use the user's past chat history (if any) or popular trends to suggest a specific generation.

## Proposed Changes

### 1. Magic Search (Search-to-Monetization)

#### [recipe_grid.dart](file:///C:/Users/mukas/StudioProjects/delisioapp/lib/widgets/home/recipe_grid.dart)
- Modify the "No recipes found" empty state.
- Add a **"Magic Search Result"** card that says: *"Can't find [Query]? Let our AI Chef create a custom version just for you!"* with a big "Generate" button.

---

### 2. Home Screen Hooks

#### [home_screen_enhanced.dart](file:///C:/Users/mukas/StudioProjects/delisioapp/lib/screens/home_screen_enhanced.dart)
- Add a new **"AI Chef's Recommendation"** section at the top (below greeting).
- This section will show a rotating "Recipe of the Day" idea (e.g., *"How about a Spicy Tuscan Salmon tonight?"*) with a "Generate Now" button.

---

### 3. High-Intent Chat Cards

#### [chat_bubble.dart](file:///C:/Users/mukas/StudioProjects/delisioapp/lib/widgets/chat/chat_bubble.dart)
- Enhance the `isPotentialRecipeDescription` UI.
- Instead of just a button, show a small **Preview Card** (Title, Prep Time, Calories) even *before* generation to "Tease" the user into clicking the button.

---

### 4. Navigation & Flow

#### [main_navigation_screen.dart](file:///C:/Users/mukas/StudioProjects/delisioapp/lib/screens/main_navigation_screen.dart)
- Ensure that if a user clicks "Generate" from the Home or Search screens, they are seamlessly transitioned to the recipe generation flow.

## Verification Plan

### Manual Verification
1.  **Search Funnel**: Search for something obscure (e.g., "Mars Chocolate Pasta"). Verify the "Magic Search" result appears. Click "Generate" and verify it leads to a Locked Recipe.
2.  **Home Hook**: Verify the new AI Chef section appears on the Home screen.
3.  **Chat Preview**: Start a chat, describe a dish, and verify the "Preview Card" trigger appears.
