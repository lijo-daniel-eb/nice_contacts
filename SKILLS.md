# Skills and Best Practices

This file captures practical engineering conventions established during this project.

## 1. Theme and UI Consistency

- Keep one source of truth for color constants in `lib/theme/my_contacts_theme.dart`.
- Do not hardcode `Color(0x...)` or `Colors.*` values in screens/widgets when a theme constant exists.
- Route runtime theming through `lib/theme/app_theme.dart` and `lib/main.dart` only.
- Prefer `Theme.of(context).colorScheme` for adaptive colors, especially for dark/light compatibility.
- For bottom navigation selected icons, ensure contrast in dark mode (fallback to readable foreground colors when accent is too dark).

## 2. Feature Removal Discipline

When removing a setting/feature, remove all dependencies end-to-end:

- UI entry in settings screen.
- Dialogs and helper methods.
- Preference keys and getters/setters.
- App startup/theme wiring.
- Help/documentation mentions.
- Verify no references remain via global search.

## 3. State and Lifecycle Safety

- Guard async UI updates with `if (!mounted) return;` before `setState` or `ScaffoldMessenger` usage.
- Dispose controllers/listeners in `dispose()`.
- If using repository listeners, detach listeners when not needed.

## 4. Analyzer and Regression Safety

- Run targeted checks after each edit (`get_errors` / file-level diagnostics).
- Run project-wide `flutter analyze` after multi-file changes.
- Treat analyzer `error` findings as blocking; `info/warning` can be addressed in follow-up passes.
- Avoid broad regex codemods unless necessary; prefer file-by-file controlled refactors.

## 5. Naming and Structure Conventions

- Use project-neutral naming (avoid leftover names from reference templates/apps).
- Keep theme-related files in `lib/theme/`.
- Remove legacy/duplicate files after migrations to avoid confusion.

## 6. Settings UX Conventions

- Settings options must map to active behavior only.
- Do not show controls for removed/inactive features.
- Keep Settings and Help pages synchronized when options are added/removed.

## 7. Android Release and Install Guidance

- Side-loaded APK installs naturally trigger Android security prompts; this is expected.
- For trusted consumer distribution, use Google Play (internal/closed/production tracks).
- Keep a stable signing key across all releases.
- Prefer Play App Signing + AAB for production delivery.

## 8. Debugging "Change Not Visible" Cases

If UI changes are not visible:

- Stop running app completely (not just hot reload).
- Run `flutter clean` and `flutter pub get`.
- Re-run app from a fresh build.
- If needed, uninstall app from emulator/device and reinstall.

## 9. Safe Refactor Checklist

Before finalizing refactors:

- Search for old identifiers and stale references.
- Verify imports are updated and unused imports removed.
- Confirm key screens still render correctly in light and dark mode.
- Re-check user-reported issue path specifically (not only generic build success).
