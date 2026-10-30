#!/bin/bash
# Previews the new showcase pages in an open sync PR and asks you to approve or decline each.
#
# Usage: review-site.sh [PR-number]   (default: the newest open showcase/sync-* PR)
#
# Builds nothing itself: the PR branch already contains the built site in docs/. It serves docs/
# locally (the way Ignite's own `ignite run` does), opens each new page, and per page asks:
#   a  approve   keep the page
#   d  decline   remove it and remember it, so `discover` never proposes it again
#   s  skip      stop here and leave the PR open
# Once every new page is decided, the PR is merged, which publishes. Declined pages are removed
# from the PR (and the site rebuilt) before the merge.
#
# Config (environment, all optional):
#   SITE_DIR   the website checkout (default: ../justinpurnell.com beside this repo)
#   NO_OPEN=1  do not open browser tabs (the URLs are still printed)
#   REVIEW_PATH_PREFIX  directories searched before the system ones (used by tests to stub gh)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="${SITE_DIR:-$(cd "$HERE/../.." && pwd)/justinpurnell.com}"
MANIFEST="$SITE_DIR/showcase-manifest.json"
export PATH="${REVIEW_PATH_PREFIX:+$REVIEW_PATH_PREFIX:}/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin:$HOME/.swiftly/bin:$PATH"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cd "$SITE_DIR"
[ -z "$(git status --porcelain)" ] || die "website tree is dirty; commit or discard first (never stashed)"

PR="${1:-$(gh pr list --state open --json number,headRefName -q '[.[] | select(.headRefName | startswith("showcase/sync-"))][0].number')}"
[ -n "$PR" ] && [ "$PR" != "null" ] || die "no open showcase sync PR"
BRANCH="$(gh pr view "$PR" --json headRefName -q .headRefName)"

git fetch -q origin
git checkout -q "$BRANCH"
git merge -q --ff-only "origin/$BRANCH"

# New slugs are the entries this branch added to the manifest relative to main.
NEW_SLUGS="$(python3 -I - "$MANIFEST" <(git show origin/main:showcase-manifest.json) <<'PY'
import json, sys
now = {e["slug"] for e in json.load(open(sys.argv[1]))["entries"]}
before = {e["slug"] for e in json.load(open(sys.argv[2]))["entries"]}
print("\n".join(sorted(now - before)))
PY
)"
[ -n "$NEW_SLUGS" ] || die "PR #$PR adds no new pages; nothing to approve (it can be merged as is)"

# First free port from 8000, as `ignite run` does.
PORT=8000
while lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do PORT=$((PORT + 1)); done
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory docs >/dev/null 2>&1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null || true' EXIT
sleep 1
echo "Previewing PR #$PR on http://localhost:$PORT/"

APPROVED=(); DECLINED=()
# The slug list comes in on fd 3 so the answer prompts below can have stdin to themselves.
while IFS= read -r slug <&3; do
  URL="http://localhost:$PORT/showcase/$slug/"
  echo
  echo "  $slug  $URL"
  [ "${NO_OPEN:-0}" = "1" ] || open "$URL"
  while true; do
    read -r -p "  [a]pprove, [d]ecline, [s]kip and stop? " ANSWER || ANSWER="s"
    case "$ANSWER" in
      a) APPROVED+=("$slug"); break ;;
      d) DECLINED+=("$slug"); break ;;
      s) echo "Stopping; PR #$PR left open."; exit 0 ;;
      *) echo "  please answer a, d or s" ;;
    esac
  done
done 3<<< "$NEW_SLUGS"

if [ "${#DECLINED[@]}" -gt 0 ]; then
  echo "Declining: ${DECLINED[*]}"
  SHOWCASE="$HERE/.build/release/showcase"
  [ -x "$SHOWCASE" ] || ( cd "$HERE" && swift build -c release 2>&1 | tail -1 )
  "$SHOWCASE" decline --manifest "$MANIFEST" "${DECLINED[@]}"
  swift run IgniteStarter 2>&1 | tail -1
  git add -A Content/showcase .showcase-state.json showcase-manifest.json docs
  git commit -q -m "chore(showcase): decline ${DECLINED[*]}" \
    -m "Declined in review; discovery will not propose them again."
  git push -q origin "$BRANCH"
fi

echo "Approved: ${APPROVED[*]:-none}. Declined: ${DECLINED[*]:-none}. Merging PR #$PR."
gh pr merge "$PR" --merge --delete-branch
git checkout -q main
git pull -q --ff-only origin main
echo "Published."
