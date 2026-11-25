# Sync (backup to Firebase)

Status: **built** (25 Nov 2026). Code: `lib/features/sync/`.

## Decisions

| Topic | Decision |
|---|---|
| Who syncs | Signed-in users only. Guests stay on the phone (a reason to sign in). |
| Source of truth | SQLite on the phone. The cloud is a copy kept in step. |
| What syncs | Entries (incl. goals), budgets, categories. |
| Where | `users/{uid}/entries`, `users/{uid}/budgets`, `users/{uid}/categories`, one document per row, document ID = row ID. |
| Conflicts | The newer `updated_at` wins. |
| Deletes | Sent as rows with `is_deleted = 1`, so other phones delete too. |
| Sign out | Backs up first, then **removes the account's data from the phone**. Data never passes from one account to another. If the backup can't finish (offline), the user is warned and can stay signed in. |
| Guest signs in | The guest's data on this phone is merged into that account. |

## When it runs

- 3 seconds after any change.
- When the app opens and when it comes back to the foreground.
- Right after sign-in (before deciding whether to show the setup sheet).
- From the ☁️ button in the sidebar.

Offline: changes wait (`sync_status` stays pending) and go up next time.

## How a sync works

For each table (categories, then budgets, then entries):

1. **Pull** rows the server changed since the last pull. Uses the
   server's write time (`server_updated_at`), not the phone's clock, and
   re-reads a 5-minute overlap. Apply each one unless this phone has a
   newer edit that isn't uploaded yet.
2. **Push** rows whose `sync_status` isn't `synced`, then mark them synced
   (only if not edited again during the upload).

**No doubles:**
- A category (same kind and name) or a budget (same category) made
  separately on two phones ends up as one row. The newer one wins, and the
  other is deleted everywhere.
- Default categories have fixed IDs (`default-expense-Food`) and the oldest
  possible time, so an account's own edited version always wins.
- Recurring copies have fixed IDs (`{rootId}-{yyyy-MM-dd}`), so two phones
  creating the same copy make one row.

**A different account on this phone:** if the signed-in user ID differs from
the last one synced here, every local row is marked for upload and the pull
starts from the beginning.

## Security

`firestore.rules` (published with `firebase deploy --only
firestore:rules`): a user can read and write only `users/{their uid}/…`.

## Tests

`test/sync_engine_test.dart` simulates two phones and one cloud: upload and
restore, edits and deletes, newer edit wins, budget and category dedupe,
recurring copies, guest merge, and sign-out isolation.
