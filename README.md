# Service Request App

An offline-first Flutter app where people raise service requests against a
**server-driven form**. Requests are saved locally first and synced to the
backend through a resilient outbox, so the app keeps working with no network and
never loses a request.

- Flutter (stable) / Dart 3, Material 3, one theme for light **and** dark.
- Clean layering: `presentation / domain / data`. **Domain and data never import
  Flutter or flutter_bloc**, so they are plain, testable Dart.
- Persistence with **sqflite only**. No Hive/Isar/Firebase.
- Networking with **Dio**; the base URL comes from `--dart-define` and has **no
  hard-coded default**.
- State management with **flutter_bloc** (one Cubit per screen, immutable
  `Equatable` states) and **get_it** for dependency injection.

## Features

| Area | Behaviour |
| --- | --- |
| New request | Form is fetched from the server and cached; rendered dynamically (text, number, dropdown, date). |
| Validation | Required, numeric min/max, text `maxLength`, conditional `visibleIf`. Hidden fields are neither validated nor submitted. |
| Unknown field types | Rendered as a non-blocking placeholder, logged, and skipped — never crash the form. |
| Offline save | Request + outbox row written in **one SQLite transaction**; UI confirms immediately. |
| Sync | FIFO outbox drain with exponential backoff + jitter, connectivity-aware, idempotent retries. |
| Failure handling | 4xx → `Failed` with the server message + manual retry. 5xx/timeout/offline → retried with backoff. |
| Recovery | On startup any request stuck in `Syncing` is reset to `Pending` and drained. |
| Visibility | Requests list with status filter chips, live offline banner, per-request sync timeline, and a diagnostics screen. |
| List states | Loading, empty and error each offer a way forward; failed cards expose a **Retry**. Pull-to-refresh triggers a sync. |
| New request form | Save button is pinned to the bottom bar, and backing out of a dirty form asks for confirmation first. |

## Architecture

```
lib/
  core/                 config, Result/AppException, Clock, IdGenerator, ChangeBus, logger
  di/injector.dart      get_it graph (overridable for tests)
  theme/                Material 3 theme + spacing tokens
  features/
    form/
      domain/           FormDefinition, FormFieldDef, FieldType, VisibleIf, FormValidator, repo + use cases
      data/             form remote (Dio) + local (sqflite) data sources, repository impl
      presentation/     NewRequestCubit + screen, FieldFactory
    requests/
      domain/           ServiceRequest, RequestStatus, SyncAttempt, RetryPolicy, repos + use cases
      data/             AppDatabase, data sources, mappers, repo impls, SyncRepository engine
      presentation/     RequestsCubit, RequestDetailCubit, DiagnosticsCubit + screens
    setup/              "missing API_BASE_URL" screen
```

Dependency direction: `presentation → domain ← data`. The domain defines
interfaces; the data layer implements them; DI wires them. `Result<T>` (Ok/Err)
is used at the boundaries instead of throwing across layers.

### Data model (SQLite)

- `form_definitions(id, version, fetched_at, json)` — PK `(id, version)`; every
  version is kept so old requests still render their original labels.
- `requests(id, form_id, form_version, title, priority, data_json, status,
  created_at, updated_at, synced_at, server_message, attempts, last_attempt_at)`
- `outbox(seq PK autoincrement, request_id UNIQUE, idempotency_key, enqueued_at)`
- `sync_attempts(id, request_id, attempt, result, http_status, duration_ms,
  message, at)` — diagnostics only, contains **no field values**.

`outbox.request_id` and `sync_attempts.request_id` are foreign keys with
`ON DELETE CASCADE`.

## Offline-first flow

1. User submits → the form is validated, hidden/empty values are stripped, and a
   UUID is generated.
2. The `requests` row **and** its `outbox` row are inserted in a single
   transaction (`RequestLocalDataSource.saveWithOutbox`). The request is
   immediately visible with status `Pending`.
3. A sync is kicked off in the background. The engine marks the row `Syncing`,
   POSTs it with `Idempotency-Key: <request UUID>`, then:
   - `201 Created` / `200 OK` (duplicate) → `Synced`, outbox row removed.
   - `4xx` → `Failed`, server message stored, surfaced for manual retry.
   - `5xx` / timeout / no connection → backoff, stays queued. Offline never
     consumes an attempt.
4. Connectivity changes, a periodic timer, and saves all trigger the drain; a
   single in-flight drain is enforced.
5. **Ordering:** items are walked by `seq`. A transient failure stops that run
   so a later request never overtakes an earlier one. A permanent `4xx` does not
   block the queue — the item is parked as `Failed` and the next one runs.

## Retry policy

`RetryPolicy` (pure Dart, unit-tested):

- Backoff = `base * factor^(attempt-1)`, capped, with **±20% jitter** (injectable
  `Random` for deterministic tests).
- Retries only transient failures (5xx, timeouts, connection errors).
- Gives up after `maxAttempts` (5) **or** a total time budget (2 min); then the
  request is `Failed` and waits for a manual retry.
- Retries reuse the original `Idempotency-Key`, so a duplicate POST returns
  `200 duplicate` instead of creating a second record.

## Idempotency

The `Idempotency-Key` header is the request UUID, stored in the outbox row. A
`200` response means the server already had it, and is treated as success.

## Running it

Prerequisites: Flutter stable, and Node 18+ for the provided mock server.

```bash
# 1. Start the mock server (from the assignment folder that contains server.js)
node server.js            # listens on :3000

# 2. Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# 3. iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

If `API_BASE_URL` is omitted the app shows a setup screen explaining how to set
it, rather than silently talking to the wrong host.

Useful server modes (see `server.js`): `online | flaky | slow | down`, and the
admin console at `/admin` for flipping modes and switching the served form
between version 2 and version 3.

## Testing

```bash
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
```

The suite (54 tests) covers:

- `FormValidator` — required, numeric bounds, `maxLength`, `visibleIf`
  (including lenient `"5"` vs `5`), hidden-field stripping, unknown types.
- `RetryPolicy` — backoff growth/cap, jitter bounds, transient vs permanent,
  attempt budget.
- `RequestLocalDataSource` — the save transaction (including **forced rollback**
  via a trigger, proving it is atomic), outbox FIFO + uniqueness, status
  filtering, startup recovery, stats, FK cascade (sqflite_common_ffi).
- `SyncRepository` — success, duplicate, permanent 4xx, transient-then-success
  with a stable idempotency key, budget exhaustion, offline, FIFO, and the
  "transient failure stops the queue" ordering rule.
- `SubmissionRemoteDataSource` — the exact `{ id, formVersion, data }` body and
  `Idempotency-Key` header, and 200-as-duplicate.
- Migration — a real v1 file reopened as v2, with rows preserved.
- Cubits and widgets — `blocTest` for the list cubit, field factory, failed-card
  Retry, setup screen, DI graph.

CI runs format check + analyze + tests on every push (`.github/workflows/ci.yml`).

## Decisions & tradeoffs

- **Server-driven form** is cached (JSON kept verbatim) so unreleased server
  properties survive round-trips; the UI only interprets the fields it knows.
- **`last_attempt_at` shipped as a v2 migration** on top of a tagged v1 schema,
  to show a real `onUpgrade` path rather than a single `onCreate`.
- **No default base URL**, per the brief: misconfiguration should be obvious.
- **Single SQLite transaction** for request + outbox removes the classic
  "saved but not queued" / "queued but not saved" bug class.
- Timeouts (5s connect, 15s read) sit above the server's 8s "slow" delay, so
  slow mode surfaces as slow success rather than a spurious timeout.

## Risks I see

- **`title` and `priority` keys are assumed.** The list/detail card reads those
  keys out of the saved data to build a summary; if the server form renamed
  them, cards fall back to a generic "Service request" and show no priority
  (`request_summary_extractor.dart`).
- **Unknown field types are dropped.** A type the app does not recognise (e.g.
  the v3 `checkbox`) renders a placeholder and is stripped before submit, so the
  value never reaches the server. Users may believe they set something.
- **Backoff does not wait across a restart.** `attempts` and `last_attempt_at`
  are stored, so the sequence continues, but on startup the drain fires
  immediately rather than sleeping until the next due time.
- **Cached form selection is by version, not freshness.** `latest()` orders by
  `version DESC`, so if the server rolled a form version back the higher cached
  copy still wins.
- **Offline detection is link-level.** `connectivity_plus` reports whether the
  device has a connection, not whether the API host is reachable; a captive
  portal will read as online and fall back to retries.
- **`sync_attempts` is never pruned** — the diagnostics log grows without bound.
- **No device run was possible**, so behaviour on a real emulator/hardware is
  not verified here; verification is `flutter analyze`, 54 automated tests, and
  the GitHub Actions run.

## Not finished / next steps

- **Background sync with `workmanager`** (the outbox is already durable, this
  would just drain it while the app is backgrounded).
- **Editing a pending request** before it syncs.
- Pagination / search on the list once volume grows.
- Conflict resolution for server-side edits (today the app is the source of
  truth until a successful POST).

## How I used AI

I used an AI assistant as a pair-programmer, not an autopilot:

- To scaffold the project, iterate on folder structure, and draft the boring
  parts (mappers, datasource plumbing).
- To pressure-test design choices — idempotency, the transaction boundary, the
  retry/backoff shape — before writing code.
- To generate and expand the test suite, then I reviewed each test to make sure
  it asserted real behaviour rather than the implementation.

Everything committed was read, run (`flutter analyze`, `flutter test`), and
understood. The architecture, the layering rule, and the trade-offs above are my
own — I can walk through any file in the repo.
