#!/usr/bin/env bash
# Run every check in the marketplace: the consistency check, then each plugin's hook tests.
# CI runs this file; `verify` runs it for a change to anything it sits above.
#
# Run:   tests/run.sh
# Exit:  0 if every suite passes, 1 otherwise.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=()

run_suite() {
  local name="$1"
  shift
  printf '== %s\n' "$name"
  "$@" || failed+=("$name")
}

run_suite "check_repo" python3 "$REPO/tests/check_repo.py" "$REPO"
for suite in "$REPO"/*/hooks/tests/run.sh; do
  [[ -f "$suite" ]] || continue
  run_suite "${suite#"$REPO"/}" bash "$suite"
done
for manifest in "$REPO"/*/hooks/hooks.json "$REPO"/*/.claude-plugin/plugin.json "$REPO/.claude-plugin/marketplace.json"; do
  jq -e . "$manifest" >/dev/null 2>&1 || failed+=("invalid JSON: ${manifest#"$REPO"/}")
done

echo
if (( ${#failed[@]} )); then
  printf 'FAIL: %s\n' "${failed[@]}"
  exit 1
fi
echo "ALL SUITES PASSED"
