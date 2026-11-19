# Club management checks

Run the migration against in-memory PostgreSQL, with no remote database changes:

```powershell
npm install --prefix .tmp/club-db-validation --no-audit --no-fund @electric-sql/pglite@0.5.16
$env:NODE_PATH = Join-Path (Get-Location) '.tmp/club-db-validation/node_modules'
node supabase/tests/club_management_local.mjs
```

The checks cover both schemas: real member lists, pending request approval and rejection,
admin promotion/demotion, owner protection, cash access, announcement permissions, and
preservation of the server-owned activity verification fields.

Prepare a Dev-only upgrade for review:

```powershell
node supabase/scripts/build-shared-dev.mjs .tmp/club-management-dev.sql --upgrade-club-management
```

The deployed Dev migration is `20261119005159_club_management_and_recording_metadata_dev.sql`.
The all-schema SQL under `supabase/review/` is a reference for local tests and has not been deployed to production.
These commands do not apply remote changes.
Apply only the approved scope, then verify RPCs, cash, and two-client chat against the deployed DB.
