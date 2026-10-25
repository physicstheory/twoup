#!/usr/bin/env bash
# publish_branch.sh <branch> <dir>: force-pushes the contents of <dir> as a one-commit branch (CI only).
set -euo pipefail
branch="$1"; src="$(cd "$2" && pwd)"
work="$(mktemp -d)"
cp -R "$src/." "$work/"
cd "$work"
git init -q
git checkout -q -b "$branch"
git config user.name "github-actions"
git config user.email "actions@users.noreply.github.com"
git add -f -A
git commit -q -m "CI output for ${GITHUB_SHA:-local}"
git push -q -f "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$branch"
