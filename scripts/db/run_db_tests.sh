#!/usr/bin/env bash
# Runs the database test suite against a throwaway supabase/postgres container.
#
#   scripts/db/run_db_tests.sh
#
# Applies supabase/migrations to an empty database, then runs
# supabase/tests/database. The canonical path is the Supabase CLI
# (supabase db reset && supabase test db); this script needs only Docker.
# The container is local and removed at the end. Nothing here touches a live project.
# Exit code is non-zero if any migration errors or any pgTAP assertion fails.
set -euo pipefail
export MSYS_NO_PATHCONV=1

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE="${PG_IMAGE:-supabase/postgres:15.8.1.085}"
NAME="wasla-db-test-$$"
PSQL_ADMIN=(docker exec -i -e PGPASSWORD=test "$NAME" psql -h localhost -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -q)

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$NAME" -e POSTGRES_PASSWORD=test "$IMAGE" >/dev/null
# The image runs its own init scripts after the first ready signal.
for _ in $(seq 1 120); do
  "${PSQL_ADMIN[@]}" -tAc "select 1 from pg_roles where rolname='authenticated'" 2>/dev/null | grep -q 1 && break
  sleep 1
done
sleep 3

"${PSQL_ADMIN[@]}" < "$ROOT/scripts/db/supabase_prelude.sql"


echo "== migrations"
shopt -s nullglob
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "   $(basename "$f")"
  docker exec -i -e PGPASSWORD=test "$NAME" psql -h localhost -U postgres -d postgres -q -v ON_ERROR_STOP=1 < "$f" >/dev/null
done

echo "== tests"
failed=0
for t in "$ROOT"/supabase/tests/database/*.sql; do
  out=$("${PSQL_ADMIN[@]}" -t -A < "$t" 2>&1) || failed=1
  { echo "$out" | grep -E '^(ok|not ok|# )' || true; } | sed "s#^#   [$(basename "$t")] #"
  if echo "$out" | grep -q -E '^not ok|ERROR|Looks like'; then
    failed=1
    { echo "$out" | grep -E 'ERROR|Looks like' || true; } | sed 's#^#      #'
  fi
done

if [[ $failed -ne 0 ]]; then echo "== RESULT: FAIL"; exit 1; fi
echo "== RESULT: PASS"
