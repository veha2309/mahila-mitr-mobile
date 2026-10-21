# Changelog

## 1.1.0 (build 3) — 2026-10-21

- Replaced Partner Home's pairing-management screen with a dedicated dashboard for shared cycle timing, messages, notes, and reflections.
- Added direct note and reflection sheets, connection settings, and nickname actions.
- Added an unconnected-partner introduction and layouts for small screens, long names, and enlarged text.
- Added Android double-back-to-close at the main screen, with a two-second confirmation window and normal navigation for child screens and sheets.
- Kept cycle dates read-only for partners and handled missing history, ongoing periods, stale estimates, and future entries.

Validation: clean Dart analysis, 106 passing regression tests, rendered UI previews, and a signed Android release build. Version remains 1.1.0; Android version code increases to 3 using the existing release signing key.

## 1.1.0 (build 2) — 2026-10-21

- Added discreet daily logging reminders for ongoing periods without a daily log, with notification taps opening today's logger.
- Added encrypted offline dashboard storage and a persistent sync queue for period entries, daily logs, profiles, notes, and reflections.
- Corrected calendar coverage so ongoing periods continue through today until an explicit end date is saved.
- Improved missing-log prompts and provided a Supabase email-code template.

Validation: Flutter analysis, regression tests, and a signed Android release build. Android version code increases to 2; the existing release signing key is retained.

## 1.0.0 (build 1)

- Refreshed home, statistics, year calendar, chat, and Moments layouts with shared typography and more usable space.
- Added illustrated note stationery and refined the note composer, inbox, and reader.
- Added floral loading indicators for actions, plus matching launcher and splash artwork.
- Preserved navigation and added display-effect controls and responsive layouts.
- Fixed reflection input state restoration during rebuilds and hot reload.
- Added app version information in Settings and dedicated Android release signing.

Validation: Flutter analysis, widget regression tests, and a signed Android release build.
