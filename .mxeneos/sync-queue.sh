#!/usr/bin/env bash
# Adds the GrapheneOS/hardened_malloc commits that are not yet on the base branch on top of it,
# oldest first, with `git cherry-pick -x`. Nothing is edited by hand. Commits listed in
# .mxeneos/skip-commits.txt are never picked. At the first commit that does not apply cleanly the
# script stops, keeps what it has picked so far, and reports that commit.
#
# Our own commits (for example the Android.bp change) stay where they are: new upstream commits
# are simply added after them.
#
# Environment: BASE_BRANCH (default main), UPSTREAM_REF (default upstream/main, a ref of the real
# GrapheneOS repository), OUT_BRANCH (default sync/<date>), RESULT_DIR (default: a temp dir).
set -euo pipefail

BASE=${BASE_BRANCH:-main}
UP=${UPSTREAM_REF:-upstream/main}
OUT=${OUT_BRANCH:-sync/$(date -u +%Y%m%d-%H%M)}
SKIPFILE=.mxeneos/skip-commits.txt
RESULT=${RESULT_DIR:-$(mktemp -d)}
mkdir -p "$RESULT"

git checkout -q -B "$OUT" "origin/$BASE"
[ -f "$SKIPFILE" ] || SKIPFILE=/dev/null

handled=$(mktemp)
# 1. everything already on the base branch (this includes the initial upstream pin)
git rev-list "origin/$BASE" > "$handled"
# 2. upstream commits recorded by `cherry-pick -x` in earlier syncs
git log "origin/$BASE" --format=%B | sed -n 's/^(cherry picked from commit \([0-9a-f]\{40\}\))$/\1/p' >> "$handled"
# 3. commits we decided never to pick
awk '!/^#/ && NF {print $1}' "$SKIPFILE" | while read -r s; do git rev-parse -q --verify "$s^{commit}" || true; done >> "$handled"
sort -u "$handled" -o "$handled"

mb=$(git merge-base "origin/$BASE" "$UP")
: > "$RESULT/picked.txt"; : > "$RESULT/conflicts.txt"
for c in $(git rev-list --reverse --no-merges "$mb..$UP"); do
  grep -qxF "$c" "$handled" && continue
  if git cherry-pick -x "$c" > /dev/null 2>&1; then
    git log -1 --format='%h %s' "$c" >> "$RESULT/picked.txt"
  else
    git cherry-pick --abort > /dev/null 2>&1 || git reset -q --hard HEAD
    git log -1 --format='%h %s' "$c" >> "$RESULT/conflicts.txt"
    break
  fi
done

echo "branch=$OUT"
echo "picked=$(wc -l < "$RESULT/picked.txt" | tr -d ' ')"
echo "conflicts=$(wc -l < "$RESULT/conflicts.txt" | tr -d ' ')"
echo "result_dir=$RESULT"
