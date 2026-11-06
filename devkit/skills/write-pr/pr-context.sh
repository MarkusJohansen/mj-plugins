#!/usr/bin/env bash
# Compact PR context: branch, commits, diffstat, and the diff truncated per file.
# Usage: pr-context.sh [base] [max_lines_per_file=120] [total_budget=2500]   (base: main, else master)
# Past the total budget, remaining files are listed with their +/- counts only.
set -euo pipefail

base="${1:-}"
max="${2:-120}"
budget="${3:-2500}"
used=0
if [[ -z "$base" ]]; then
  for b in main master origin/main origin/master; do
    git rev-parse --verify --quiet "$b" >/dev/null && { base="$b"; break; }
  done
fi
[[ -n "$base" ]] || { echo "no base branch found (pass one)" >&2; exit 1; }

skip='(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|uv\.lock|poetry\.lock|Cargo\.lock|go\.sum|.*\.min\.(js|css)|.*\.map)$|(^|/)(dist|build|generated|__generated__|vendor)/'

echo "## Branch: $(git rev-parse --abbrev-ref HEAD) (base: $base)"
echo
echo "## Commits"
git log --oneline "$base..HEAD"
echo
echo "## Diffstat"
git diff --stat=120 "$base...HEAD"
echo
echo "## Diff (first $max lines per file, $budget in total; skipped: lockfiles, generated, binary)"
git diff --name-only "$base...HEAD" | while IFS= read -r f; do
  if [[ "$f" =~ $skip ]]; then
    echo "### $f — skipped (lockfile/generated)"
    continue
  fi
  if git diff --numstat "$base...HEAD" -- "$f" | grep -q '^-'; then
    echo "### $f — skipped (binary)"
    continue
  fi
  if (( used >= budget )); then
    echo "### $f — not shown, budget reached ($(git diff --numstat "$base...HEAD" -- "$f" | awk '{print "+"$1" -"$2}'))"
    continue
  fi
  out=$(git diff "$base...HEAD" -- "$f")
  n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  echo "### $f"
  printf '%s\n' "$out" | head -n "$max"
  used=$(( used + (n < max ? n : max) ))
  (( n > max )) && echo "… $((n - max)) more lines (git diff $base...HEAD -- '$f')"
  echo
done
