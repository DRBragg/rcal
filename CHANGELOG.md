# Changelog

## [Unreleased]

## [0.2.1] - 2026-02-26

### Fixed

- Improved auth flow: replaced deprecated OOB OAuth with loopback (with headless fallback), unified token storage, fixed auto-refresh for stored tokens, and improved error handling ([#12])

## [0.2.0] - 2026-02-26

### Added

- Ability to specify or change an event's color when adding or editing ([#4])
- Recurring event support ([#5])
- Ability to mark events as "free" for scheduling/planning purposes ([#6])
- Basic CI workflow

### Fixed

- Time parsing now uses the user's local timezone instead of system timezone (UTC), which caused events to appear hours off for non-UTC users ([#1])

## [0.1.1] - 2026-02-26

### Fixed

- `--days` flag and date range arguments causing "no implicit conversion of Date into String" error ([#3])

## [0.1.0] - 2026-02-06

### Added

- Initial release
- Google Calendar CLI with natural language date parsing (via Chronic)
- Event management: create (`add`, `quick`), edit, and view (`agenda`) events
- ICS file import with calendar selection
- Predicate filtering (`--must-be`, `--must-not-be`) for recurring, declined, all-day, one-on-one, and more
- Multiple calendar support
- Duration parsing (`30m`, `1h30m`, `1.5h`)
- Calendar listing
- OAuth 2.0 authentication via `rcal init`
- XDG Base Directory compliant configuration
