#!/usr/bin/env bash
# Tests for the shell-habits and name-guard hooks. Each case feeds a hook event on stdin.
set -u

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX"
passed=0 failed=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1)); echo "  FAIL  $name: expected '$expected', got '$actual'"
  fi
}

habit_decision() {
  local session="$1" command="$2"
  jq -n --arg session "$session" --arg command "$command" '{session_id: $session, tool_input: {command: $command}}' \
    | python3 "$HOOKS/shell-habits.py" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "allow"'
}

check "re-reading CLAUDE.md is nudged" deny "$(habit_decision s1 'cat CLAUDE.md')"
check "a nudge fires once per session" allow "$(habit_decision s1 'cat CLAUDE.md')"
check "hand-run pytest is nudged" deny "$(habit_decision s2 'cd libs/x && .venv/bin/pytest -q | tail -5')"
check "branch log is nudged" deny "$(habit_decision s3 'git log --oneline origin/main..HEAD')"
check "python string replace is nudged" deny "$(habit_decision s4 "s=open('a').read(); s=s.replace('a','b'); open('a','w').write(s)")"
check "verify itself passes" allow "$(habit_decision s5 'verify --all')"
check "unrelated commands pass" allow "$(habit_decision s6 'ls -la')"
check "every hit is logged" 5 "$(wc -l < "$SANDBOX/.claude/shell-habits/hits.jsonl" | tr -d ' ')"

guard_decision() {
  local tool="$1" cwd="$2" input="$3"
  jq -n --arg tool "$tool" --arg cwd "$cwd" --argjson input "$input" '{tool_name: $tool, cwd: $cwd, tool_input: $input}' \
    | python3 "$HOOKS/name-guard.py" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "allow"'
}

WORK="$SANDBOX/work/acme"
mkdir -p "$WORK" "$SANDBOX/.claude"
check "no config means no guard" allow "$(guard_decision Write /tmp '{"file_path":"/tmp/n.md","content":"Acme"}')"
printf '{"terms": ["Acme", "widget-repo"], "allowed_roots": ["%s"]}' "$WORK" > "$SANDBOX/.claude/private-terms.json"
check "a term written outside the roots is denied" deny \
  "$(guard_decision Write /tmp '{"file_path":"/tmp/notes.md","content":"Notes on the ACME widget"}')"
inside_root=$(jq -nc --arg path "$WORK/notes.md" '{file_path: $path, content: "Acme"}')
claude_folder=$(jq -nc --arg path "$SANDBOX/.claude/projects/${WORK//\//-}/memory/m.md" '{file_path: $path, content: "Acme"}')
check "a term written inside a root is allowed" allow "$(guard_decision Write /tmp "$inside_root")"
check "an edit adding a term outside is denied" deny \
  "$(guard_decision Edit /tmp '{"file_path":"/tmp/a.py","old_string":"x","new_string":"see widget-repo"}')"
check "a word containing a term is not a match" allow \
  "$(guard_decision Write /tmp '{"file_path":"/tmp/a.md","content":"Acmeville"}')"
check "a commit naming a term outside the roots is denied" deny \
  "$(guard_decision Bash /tmp '{"command":"git commit -m \"port the Acme parser\""}')"
check "reading a work path from outside is allowed" allow \
  "$(guard_decision Bash /tmp "{\"command\":\"ls $WORK\"}")"
check "a commit inside a root is allowed" allow \
  "$(guard_decision Bash "$WORK" '{"command":"git commit -m \"Acme fix\""}')"
check "Claude's own folders for a root are allowed" allow "$(guard_decision Write /tmp "$claude_folder")"
check "the guard denies, not just a broken input" deny \
  "$(guard_decision Write /tmp "$(jq -nc '{file_path: "/tmp/x.md", content: "Acme"}')")"

echo "$passed passed, $failed failed"
(( failed == 0 ))
