#!/bin/sh
# Same-named skills in the global skillshare layer and in a project must sit
# at one version. A project's CI does not see the global layer, so the check
# lives here and runs against projects listed in a local file outside Git.
#
# Usage: check-skill-versions.sh [projects-file]
#
# projects-file holds one project root per line; # starts a comment. Default:
# ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/projects. No file means nothing
# to compare. SKILLSHARE_METADATA overrides the global registry path.
#
# Versions are compared by tree hash: the same skill text at two commits is
# one version. Exit 0 all match, 1 a mismatch or a listed project without a
# skillshare lockfile, 2 the check could not run.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib/skillshare.sh"

list=${1:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/projects}
meta=${SKILLSHARE_METADATA:-$(global_metadata)}

if [ ! -f "$list" ]; then
  echo "check-skill-versions: no project list at $list, nothing to compare"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "check-skill-versions: jq not found" >&2
  exit 2
fi
if [ ! -f "$meta" ]; then
  echo "check-skill-versions: global registry not found: $meta" >&2
  exit 2
fi

status=0
compared=0
while IFS= read -r line || [ -n "$line" ]; do
  project=$(printf '%s' "$line" | tr -d '\r' | sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -n "$project" ] || continue
  lock="$project/.skillshare/skills.lock.json"
  if [ ! -f "$lock" ]; then
    echo "MISSING  $project: no .skillshare/skills.lock.json"
    status=1
    continue
  fi
  compared=$((compared + 1))
  report=$(jq -r -n --slurpfile g "$meta" --slurpfile p "$lock" '
    $g[0].entries as $ge
    | $p[0].skills | to_entries[]
    | select($ge[.key] != null)
    | ($ge[.key]) as $e
    | if .value.tree_hash == $e.tree_hash
      then "OK       \(.key)"
      else "MISMATCH \(.key): global \($e.branch // "unpinned") \(($e.commit // $e.version // "?")[0:7]), project \(.value.commit[0:7])"
      end')
  [ -n "$report" ] || report="OK       no skills shared with the global layer"
  printf '%s\n' "$report" | sed "s|^\([A-Z]* *\)|\1$project: |"
  case $report in *MISMATCH*) status=1 ;; esac
done < "$list"

echo "check-skill-versions: $compared project(s) compared"
exit $status
