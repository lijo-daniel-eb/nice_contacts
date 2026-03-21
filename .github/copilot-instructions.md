# Copilot Instructions for My Contacts

These are always-on repository instructions for future changes.

## Core Engineering Rules

- Keep one source of truth for color constants in `lib/theme/my_contacts_theme.dart`.
- Do not hardcode `Color(0x...)` or `Colors.*` in screens/widgets when a theme constant exists.
- Route runtime theming through `lib/theme/app_theme.dart` and `lib/main.dart`.
- Prefer `Theme.of(context).colorScheme` for adaptive colors and dark-mode safety.
- Ensure selected bottom-nav icons remain visible in dark theme (use readable fallback when accent contrast is low).

## Feature Removal Rules

When removing a setting/feature, remove all dependencies end-to-end:

- Settings UI entry.
- Dialogs/helper methods.
- Preference keys/getters/setters.
- Startup wiring and runtime usage.
- Help/documentation mentions.
- Verify no references remain via workspace search.

## Safety and Validation

- Guard async UI updates with `if (!mounted) return;` before `setState`/`ScaffoldMessenger`.
- Dispose controllers/listeners in `dispose()`.
- Run targeted diagnostics after edits.
- Run `flutter analyze` after multi-file changes.
- Treat analyzer `error` findings as blocking.
- Prefer file-by-file refactors over broad regex codemods.

## Structure and Naming

- Use project-neutral names.
- Keep theme files under `lib/theme/`.
- Remove obsolete duplicate files after migrations.

## Settings and Help Consistency

- Settings options must map to active behavior only.
- Do not expose controls for removed/inactive features.
- Keep Settings and Help pages synchronized.

## Change Visibility Troubleshooting

If a user reports a missing UI change, verify with clean rebuild steps:

- Stop app fully.
- Run `flutter clean` and `flutter pub get`.
- Re-run app.
- If needed, reinstall on emulator/device.
