---
applyTo: "lib/**/*.dart"
description: "Use for Flutter UI/theme work: enforce centralized colors, colorScheme usage, dark-mode contrast, and complete feature-removal cleanup across settings/preferences/help."
---

# UI and Theme Rules

## Color and Theme Source of Truth

- Use colors from `lib/theme/my_contacts_theme.dart`.
- Do not introduce new inline `Color(0x...)` or `Colors.*` values in UI files if an equivalent theme constant exists.
- Use `Theme.of(context).colorScheme` for semantic/adaptive colors.

## Dark Mode Visibility

- Validate icon/text contrast in dark mode.
- For selected nav/action icons, use fallback foreground colors if accent luminance causes low contrast.

## When Removing a UI Setting

Remove all connected dependencies in the same change:

1. Settings tile/control.
2. Related dialogs/helpers.
3. Preferences service key/getter/setter.
4. Runtime usage in app/theme wiring.
5. Help/documentation references.
6. Global search verification for stale references.

## Validation Checklist

- Run diagnostics for edited files.
- Run `flutter analyze` after multi-file edits.
- Confirm no analyzer errors introduced by theme/settings changes.
