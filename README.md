# Lumen – Carbon Companion

Lumen is a Flutter carbon-footprint companion with local account registration,
calculation, and history features.

## Application and database audit

The app uses SQLite through `sqflite`. On native platforms the database is
stored in the application database directory. On Chrome it uses
`sqflite_common_ffi_web` and browser-local storage. These are separate local
databases, not a shared or centralized service.

The active database tables are:

- `users`: `id`, `name`, `email`, `password_salt`, `password_hash`, `role`,
  `created_at`.
- `carbon_calculations`: `id`, nullable `user_id`, `date`,
  `transport_emission`, `electricity_emission`, `food_emission`,
  `travel_emission`, `total_emission`, `transport_distance`,
  `electricity_units`, `food_type`, `travel_distance`, `travel_type`.
- `activity_logs`: `id`, nullable `user_id`, `event_type`, `occurred_at`,
  `details`, unique `dedupe_key`.

The app screens are the Lumen landing page, login/register, Overview,
Calculate, History, and the admin dashboard. Calculations implement transport,
home electricity, and diet factors; the schema also stores travel emission and
the calculation inputs above. Activities are recorded for successful
registration, login, logout, calculation completion, calculation save/delete,
and initial admin setup. Profile editing is not implemented.

Versioned migrations add the user role/registration date, nullable calculation
ownership, and the activity log. Pre-existing calculation rows have no reliable
owner or time-of-day, so they remain unassigned and their prior activity cannot
be reconstructed. New calculations are associated with the signed-in user and
appear only in that user's History. The admin total emissions value sums the
stored `total_emission` values; it includes older unassigned records.

## Admin dashboard

Administrators can view overview statistics, searchable and filterable users,
saved calculation records with owner information when available, recorded
activity, and a database connection/table-count summary. Passwords, salts,
hashes, and session values are not queried for display. Desktop uses a
navigation sidebar; compact layouts use a bottom navigation bar. Database
errors and empty data sets have distinct messages.

### Configure an admin for local development

There is no trusted backend. For a local Chrome development/demo run:

1. Run `flutter run -d chrome` (a debug build).
2. Register a normal account and log in. Registration always creates `USER`.
3. If the local database has no administrator, use the debug-only first-admin
   setup action on the signed-in dashboard for the intended local admin.
4. Open the administrator shield button to access the dashboard.

First-admin setup is disabled in release builds and only succeeds while the
local database has no administrators. It is not a production provisioning
mechanism.

### Security and deployment limitations

Role checks are enforced in both the application service and database
data-access methods against the current local SQLite role/session;
registration cannot select a role, and calculation reads/deletes are scoped to
the current account. However, the browser/device owner can edit local storage
or run modified client code. Client-side checks are **not production
security**. Accounts, activity, and dashboard data are not shared across
browsers or devices.

A production deployment needs a trusted backend that authenticates users,
enforces authorization for every admin-data request, owns a centralized
database, and provisions the first administrator out of band. No backend
credentials or privileged secrets should be embedded in the Flutter app.

## Verification

Run:

```shell
flutter pub get
flutter analyze
flutter test
```

In Chrome, verify:

1. Register and log in with a normal account; verify it is a `USER`.
2. Confirm direct navigation to the admin page is rejected for a non-admin.
3. Use debug-only setup for the initial local admin, then reopen the dashboard.
4. Verify overview counts and emissions, user filters, calculation owner/date/
   category fields, activity event names/timestamps, and database table counts.
5. Create and save a calculation. Confirm its owner and saved/completed events
   appear in the admin view, while the record appears in that user's History.
6. Sign out and confirm protected admin data cannot be loaded without a valid
   admin session.
7. Restart the app and confirm the splash transitions to the restored session;
   clear browser storage or sign out and confirm it transitions to login.
8. Use a smaller browser width to check the mobile navigation and horizontal
   table scrolling.
