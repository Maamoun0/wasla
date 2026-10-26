#!/usr/bin/env bash
# Runs the database test suite against a throwaway supabase/postgres container.
#
#   scripts/db/run_db_tests.sh                    # baseline = supabase/migrations only
#   LEGACY_BASELINE=1 scripts/db/run_db_tests.sh  # reconstruct schema from legacy SQL first
#
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
until docker exec "$NAME" pg_isready -U postgres -h localhost >/dev/null 2>&1; do sleep 1; done
# The image runs its own init scripts after the first ready signal.
until "${PSQL_ADMIN[@]}" -c "select 1 from pg_roles where rolname='authenticated'" 2>/dev/null | grep -q 1; do sleep 1; done
sleep 3

"${PSQL_ADMIN[@]}" < "$ROOT/scripts/db/supabase_prelude.sql"

if [[ "${LEGACY_BASELINE:-0}" == "1" ]]; then
  echo "== legacy reconstruction (errors are reported, not fatal)"
  grep -v -E '^\s*(#|$)' "$ROOT/scripts/db/legacy_reconstruction.txt" | while read -r f; do
    errs=$(docker exec -i -e PGPASSWORD=test "$NAME" psql -h localhost -U postgres -d postgres -q -v ON_ERROR_STOP=0 < "$ROOT/$f" 2>&1 | grep -c ERROR || true)
    echo "   $f: $errs error(s)"
  done
  "${PSQL_ADMIN[@]}" < "$ROOT/scripts/db/supabase_default_grants.sql"
fi

echo "== migrations"
shopt -s nullglob
for f in "$ROOT"/supabase/migrations/*.sql; do
  echo "   $(basename "$f")"
  docker exec -i -e PGPASSWORD=test "$NAME" psql -h localhost -U postgres -d postgres -q -v ON_ERROR_STOP=1 < "$f"
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
