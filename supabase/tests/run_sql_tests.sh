#!/usr/bin/env bash
# Runs every migration plus supabase/tests/sql_tests.sql on a THROWAWAY local PostgreSQL (needs psql, createdb, a server).
# Usage:  PGHOST=/tmp PGPORT=54329 PGUSER=postgres ./supabase/tests/run_sql_tests.sh
# It creates a scratch database, loads the stub in 00_supabase_stub.sql, applies the migrations, runs the tests, drops the database.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# setup_all.sql (what Nathan pastes) must be exactly the migrations, in order.
cp "$here/../setup_all.sql" /tmp/mh_setup_all_before.sql
"$here/../build_setup_all.sh" >/dev/null
cmp "$here/../setup_all.sql" /tmp/mh_setup_all_before.sql || { echo "setup_all.sql was stale; it has been rebuilt. Commit it."; exit 1; }
db="mh_test_$$"
createdb "$db"
trap 'dropdb --if-exists "$db" >/dev/null 2>&1 || true' EXIT
run() { psql -v ON_ERROR_STOP=1 -q -X -d "$db" "$@"; }
run -f "$here/00_supabase_stub.sql"
for f in "$here"/../migrations/*.sql; do echo "apply $(basename "$f")"; run -f "$f"; done
run -f "$here/sql_tests.sql"
# the one-paste file must also load on a fresh database
db2="${db}_all"; createdb "$db2"; psql -v ON_ERROR_STOP=1 -q -X -d "$db2" -f "$here/00_supabase_stub.sql" && psql -v ON_ERROR_STOP=1 -q -X -d "$db2" -f "$here/../setup_all.sql" >/dev/null; dropdb "$db2"; echo "setup_all.sql loads on a fresh database"
echo "SQL TESTS PASSED"
