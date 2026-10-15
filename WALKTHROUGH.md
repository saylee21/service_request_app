# Walkthrough

A short, reproducible tour of the app and the decisions behind it. Roughly
5–8 minutes.

## 0. Prerequisites

```bash
flutter --version        # stable, Dart 3
node --version           # 18+
```

## 1. Start the mock server

From the folder that contains `server.js`:

```bash
node server.js
```

It listens on `:3000` and exposes a mode switch (`online | flaky | slow | down`)
and a form-version switch (version 2 ↔ version 3) on the admin page at
`http://localhost:3000/admin`.

## 2. Run the app

```bash
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Point out: no default URL is baked in. Run `flutter run` without the
`--dart-define` to see the **"API base URL not configured"** screen.

## 3. Create a request (server-driven form)

Tap **New request**. The form is fetched from the server and rendered from JSON:

- Text, number, dropdown and date fields.
- Pick `priority = High` to reveal the conditional **reason** field (`visibleIf`).
- Leave a required field empty → inline validation, submit is blocked.
- Point out the **"Form version N"** label and the cache: kill the server, reopen
  the form → it still renders from cache.

## 4. Offline-first save

1. Toggle the server to **down** (or enable airplane mode).
2. Create a request → it saves instantly and the list shows **Pending** with the
   offline banner.
3. Kill and relaunch the app → the request is still there.

Talk track: the `requests` row and its `outbox` row are written in **one
transaction**, so a request can never be saved without being queued (or vice
versa).

## 5. Resilient sync

1. Set the server back to **flaky** and hit the sync button.
2. Watch a `Failed`/retry cycle: backoff with jitter, then success.
3. Set **down** and watch transient failures stay `Pending` — going offline
   consumes **no** attempt.
4. Reconnect → the connectivity listener drains the outbox automatically.

Retries reuse the original `Idempotency-Key` (the request UUID), so a duplicate
POST returns `200 duplicate` instead of creating two records.

Talk track: a transient failure stops that drain run so a later request never
overtakes an earlier one; a permanent `4xx` does not block the queue.

## 6. Permanent failure + manual retry

Force a `4xx` (e.g. send an invalid value the server rejects): the request becomes
**Failed** with the server message. Open its detail and press **Retry now**.

## 7. Detail + diagnostics

- Request detail: status, submitted values (labelled via the **original form
  version**), and the **sync timeline** (attempt #, HTTP status, duration).
- Diagnostics screen: outbox size, per-status counts, last success/error, app +
  schema version, a **copy logs** button, and the recent attempts log. **No field
  values are ever logged.**
- On the list, a **Failed** card shows the server message and a **Retry** action.

## 8. Schema migration (v2)

The repo history tells the story:

```bash
git log --oneline
git show v1-schema:lib/features/requests/data/datasources/app_database.dart
```

- **v1** (tag `v1-schema`) ships the whole app with no `last_attempt_at`.
- **v2** bumps the schema and adds the column in `onUpgrade` via
  `ALTER TABLE requests ADD COLUMN last_attempt_at TEXT`. Fresh installs run the
  same migration so the schema has one source of truth.
- `test/migration_test.dart` opens a real v1 database, upgrades it, and asserts
  existing rows survive.

## 9. Architecture in one sentence

`presentation → domain ← data`; domain and data are Flutter-free; `/domain`
defines the interfaces, `/data` implements them (Dio + sqflite), and `get_it`
wires everything — which is exactly why the sync engine, validator and retry
policy are testable without a device.

## 10. Verify

```bash
flutter analyze
flutter test          # 54 tests
```
