#!/bin/sh
# Fixtures for check-skill-versions.sh: no network, no real skillshare.
# Usage: sh bin/check-skill-versions-test.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
check="$here/check-skill-versions.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

failed=0
# expect <name> <exit code> <text the output must contain>
expect() {
  name=$1 want=$2 text=$3
  shift 3
  set +e
  out=$("$@" 2>&1)
  got=$?
  set -e
  if [ "$got" -ne "$want" ] || ! printf '%s' "$out" | grep -qF -- "$text"; then
    echo "FAIL $name: exit $got (want $want), output:"
    printf '%s\n' "$out" | sed 's/^/  /'
    failed=1
  else
    echo "ok   $name"
  fi
}

global() {
  cat > "$tmp/metadata.json" <<EOF
{"version":1,"entries":{
  "skillshare":{"branch":"$1","commit":"$2","tree_hash":"$3"},
  "my-human-text":{"branch":"v0.1.0","commit":"81a4971a","tree_hash":"aaaa"}}}
EOF
}

project() {
  mkdir -p "$tmp/$1/.skillshare"
  cat > "$tmp/$1/.skillshare/skills.lock.json" <<EOF
{"version":1,"skills":{
  "skillshare":{"source":"x","commit":"$2","tree_hash":"$3"},
  "verify-this":{"source":"y","commit":"cccccccc","tree_hash":"cccc"}}}
EOF
}

project same 1111111aaaa 1111
project ahead 2222222bbbb 2222
printf '# comment line\n%s\n\n' "$tmp/same" > "$tmp/list-same"
printf '%s  # trailing comment\r\n' "$tmp/ahead" > "$tmp/list-ahead"
printf '%s\n' "$tmp/nowhere" > "$tmp/list-missing"

export SKILLSHARE_METADATA="$tmp/metadata.json"

global v0.21.10 1111111aaaa 1111
expect "same version passes" 0 "OK       $tmp/same: skillshare" sh "$check" "$tmp/list-same"
expect "global behind project is named" 1 "MISMATCH $tmp/ahead: skillshare: global v0.21.10 1111111, project 2222222" sh "$check" "$tmp/list-ahead"
expect "listed project without lockfile fails" 1 "MISSING  $tmp/nowhere" sh "$check" "$tmp/list-missing"
expect "no project list compares nothing" 0 "nothing to compare" sh "$check" "$tmp/absent"

global v0.23.0 9999999dddd 1111
expect "same tree at another commit is one version" 0 "OK       $tmp/same: skillshare" sh "$check" "$tmp/list-same"

SKILLSHARE_METADATA="$tmp/none.json"
expect "missing global registry cannot run" 2 "global registry not found" sh "$check" "$tmp/list-same"

exit $failed
