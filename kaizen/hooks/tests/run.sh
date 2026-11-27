#!/usr/bin/env bash
# Tests for the kaizen hooks and the verify helper. Each hook case feeds an event on stdin.
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
check "uv run ruff check is nudged" deny "$(habit_decision s7 'uv run ruff check --fix')"
check "a commit message naming pytest passes" allow "$(habit_decision s8 'git commit -m "Speed up pytest fixtures"')"
check "grep for pytest passes" allow "$(habit_decision s9 'grep -n pytest pyproject.toml')"
check "branch log is nudged" deny "$(habit_decision s3 'git log --oneline origin/main..HEAD')"
check "python string replace is nudged" deny "$(habit_decision s4 "s=open('a').read(); s=s.replace('a','b'); open('a','w').write(s)")"
check "verify itself passes" allow "$(habit_decision s5 'verify --all')"
check "unrelated commands pass" allow "$(habit_decision s6 'ls -la')"
check "every hit is logged" 6 "$(wc -l < "$SANDBOX/.claude/shell-habits/hits.jsonl" | tr -d ' ')"
check "re-running the nudged command is logged as reissued" 1 \
  "$(jq -s '[.[] | select(.outcome == "reissued")] | length' "$SANDBOX/.claude/shell-habits/hits.jsonl")"
habit_decision s1 'cat AGENTS.md' >/dev/null
check "a different later call is logged as later" 1 \
  "$(jq -s '[.[] | select(.outcome == "later")] | length' "$SANDBOX/.claude/shell-habits/hits.jsonl")"

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

PERSONAL="$SANDBOX/personal"
mkdir -p "$PERSONAL"
check "a commit elsewhere through cd, started inside a root, is denied" deny \
  "$(guard_decision Bash "$WORK" "{\"command\":\"cd $PERSONAL && git commit -m 'port the Acme parser'\"}")"
check "a commit elsewhere through git -C, started inside a root, is denied" deny \
  "$(guard_decision Bash "$WORK" "{\"command\":\"git -C $PERSONAL commit -m 'Acme parser'\"}")"
check "git -C does not hide a commit from the guard" deny \
  "$(guard_decision Bash /tmp "{\"command\":\"git -C $PERSONAL commit -m 'Acme parser'\"}")"
check "a file written elsewhere from inside a root is denied" deny \
  "$(guard_decision Bash "$WORK" "{\"command\":\"echo 'Acme plan' > $PERSONAL/notes.md\"}")"
check "a commit inside a root that silences stderr is allowed" allow \
  "$(guard_decision Bash "$WORK" '{"command":"git commit -m \"Acme fix\" 2>/dev/null"}')"
check "a log sent to a temp file from inside a root is allowed" allow \
  "$(guard_decision Bash "$WORK" '{"command":"echo \"Acme run\" > /tmp/kaizen-test.log"}')"
check "a cd that stays inside the root is allowed" allow \
  "$(guard_decision Bash "$WORK" "{\"command\":\"cd $WORK/sub && git commit -m 'Acme fix'\"}")"
check "reading a term with stderr silenced is not a write" allow \
  "$(guard_decision Bash /tmp '{"command":"grep -c Acme notes.md 2>/dev/null"}')"

lesson_decision() {
  local session="$1" transcript="$2"
  jq -n --arg session "$session" --arg transcript "$transcript" '{session_id: $session, transcript_path: $transcript}' \
    | python3 "$HOOKS/lesson-check.py" | jq -rs '.[0].decision // "allow"'
}

CORRECTED="$SANDBOX/corrected.jsonl"
LEARNED="$SANDBOX/learned.jsonl"
cat > "$CORRECTED" <<'TRANSCRIPT'
{"type":"user","message":{"role":"user","content":"add a retry to the fetch"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/repo/fetch.py"}}]}}
{"type":"user","message":{"role":"user","content":"no, use the shared retry helper"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/repo/fetch.py"}}]}}
TRANSCRIPT
cp "$CORRECTED" "$LEARNED"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/repo/.claude/skills/fetch/SKILL.md"}}]}}' >> "$LEARNED"
echo 'not json at all' > "$SANDBOX/garbage.jsonl"
mkdir -p "$SANDBOX/.claude/lesson-check"
touch -t 202001010000 "$SANDBOX/.claude/lesson-check/long-gone-session"

check "a correction with no lesson written blocks the stop" block "$(lesson_decision l1 "$CORRECTED")"
check "the stop is blocked once per session" allow "$(lesson_decision l1 "$CORRECTED")"
check "a lesson written after the correction lets Claude stop" allow "$(lesson_decision l2 "$LEARNED")"
check "an unreadable transcript lets Claude stop" allow "$(lesson_decision l3 "$SANDBOX/garbage.jsonl")"
check "a missing transcript lets Claude stop" allow "$(lesson_decision l4 "$SANDBOX/none.jsonl")"
check "markers of long-finished sessions are pruned" 0 "$(find "$SANDBOX/.claude/lesson-check" -name long-gone-session | wc -l | tr -d ' ')"

touch -t 202001010000 "$SANDBOX/.claude/shell-habits/old-session.hand-verify"
habit_decision s10 'cat CLAUDE.md' >/dev/null
check "shell-habits prunes markers of long-finished sessions" 0 "$(find "$SANDBOX/.claude/shell-habits" -name 'old-session.*' | wc -l | tr -d ' ')"
check "shell-habits keeps its hit log" 1 "$(find "$SANDBOX/.claude/shell-habits" -name hits.jsonl | wc -l | tr -d ' ')"

echo 'half-written line' >> "$SANDBOX/.claude/shell-habits/hits.jsonl"
mkdir -p "$SANDBOX/.claude/projects"
check "shell-patterns survives a corrupt hit log" true \
  "$(python3 "$HOOKS/../scripts/shell-patterns.py" --days 7 | jq '.habit_hits | length > 0')"

VERIFY="$HOOKS/../scripts/verify"
PROJECT="$SANDBOX/project"
mkdir -p "$PROJECT/tool/tests"
git -C "$PROJECT" init -q
printf '#!/usr/bin/env bash\necho fine\n' > "$PROJECT/tool/good.sh"
printf '#!/usr/bin/env bash\necho suite-ran\n' > "$PROJECT/tool/tests/run.sh"
git -C "$PROJECT" add .
git -C "$PROJECT" -c user.email=t@t -c user.name=t commit -q -m init

verify_output() { (cd "$PROJECT" && python3 "$VERIFY" "$@" 2>&1; echo "exit=$?"); }

check "verify has nothing to do on a clean tree" 1 "$(verify_output | grep -c 'no changed')"
check "verify takes a directory and checks a clean tree" 1 "$(verify_output tool | grep -c 'ok    tool/tests/run.sh')"
check "verify --no-tests skips the script suite" 0 "$(verify_output --no-tests tool | grep -c 'tests/run.sh')"
if command -v ruff >/dev/null; then
  printf 'x = {  "a":1 }\n' > "$PROJECT/tool/unformatted.py"
  git -C "$PROJECT" add tool/unformatted.py
  git -C "$PROJECT" -c user.email=t@t -c user.name=t commit -q -m "add an unformatted file"
  verify_output --no-tests tool >/dev/null
  check "verify on a directory reports and does not reformat" 'x = {  "a":1 }' "$(cat "$PROJECT/tool/unformatted.py")"
  printf '\n' >> "$PROJECT/tool/unformatted.py"
  verify_output --no-tests >/dev/null
  check "verify on a changed file formats it" 'x = {"a": 1}' "$(cat "$PROJECT/tool/unformatted.py")"
  git -C "$PROJECT" checkout -q -- tool/unformatted.py
fi
printf 'if then\n' > "$PROJECT/tool/broken.sh"
check "verify picks up an untracked shell file and fails on a syntax error" 1 "$(verify_output | grep -c 'FAIL  bash -n broken.sh')"
check "verify exits non-zero when a step fails" 1 "$(verify_output | grep -c 'exit=1')"
rm "$PROJECT/tool/broken.sh"
printf '#!/usr/bin/env bash\necho assertion failed; exit 1\n' > "$PROJECT/tool/tests/run.sh"
check "verify reports a failing script suite" 1 "$(verify_output | grep -c 'FAIL  tool/tests/run.sh')"

# --- the usage miner: token totals per model, main sessions apart from subagents
MINE="$HOOKS/../skills/introspect/mine.py"
FIXTURE="$SANDBOX/claude-fixture"
mkdir -p "$FIXTURE/projects/proj/sess1/subagents"
now=$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat())')
turn() { # turn ID MODEL OUTPUT_TOKENS -> one assistant transcript line
  jq -cn --arg id "$1" --arg model "$2" --argjson out "$3" --arg t "$now" \
    '{type: "assistant", timestamp: $t, message: {id: $id, model: $model, content: [],
      usage: {input_tokens: 10, output_tokens: $out, cache_read_input_tokens: 100, cache_creation_input_tokens: 5}}}'
}
{ turn a big 40; turn a big 70; turn b big 30; turn c small 5; } > "$FIXTURE/projects/proj/sess1.jsonl"
turn d small 200 > "$FIXTURE/projects/proj/sess1/subagents/agent-1.jsonl"
python3 "$MINE" --days 7 --claude-dir "$FIXTURE" --out "$SANDBOX/mined.json" >/dev/null 2>&1
check "a streamed reply is counted once, at its largest count" 100 "$(jq '.usage.tokens.main.big.output' "$SANDBOX/mined.json")"
check "input and cache tokens are summed per message" "20 200 10" \
  "$(jq -r '.usage.tokens.main.big | "\(.input) \(.cache_read) \(.cache_write)"' "$SANDBOX/mined.json")"
check "subagent tokens are kept apart from the main session" "5 200" \
  "$(jq -r '"\(.usage.tokens.main.small.output) \(.usage.tokens.subagents.small.output)"' "$SANDBOX/mined.json")"

# --- weekly.sh: leaves unless the newest report is a week old
WEEKLY="$HOOKS/../scripts/weekly.sh"
REPORTS="$SANDBOX/reports"
mkdir -p "$REPORTS" "$HOME/.local/bin"
printf '#!/bin/sh\necho called >> "%s/claude.calls"\n' "$SANDBOX" > "$HOME/.local/bin/claude"
chmod +x "$HOME/.local/bin/claude"
days_ago() { python3 -c 'import datetime, sys; print(datetime.date.today() - datetime.timedelta(days=int(sys.argv[1])))' "$1"; }
claude_ran() { [[ -f "$SANDBOX/claude.calls" ]] && echo yes || echo no; }
touch "$REPORTS/$(days_ago 3).md"
KAIZEN_REPORT_DIR="$REPORTS" bash "$WEEKLY" >/dev/null 2>&1
check "weekly.sh leaves quietly when the newest report is 3 days old" "0 no" "$? $(claude_ran)"
rm "$REPORTS"/*.md
touch "$REPORTS/$(days_ago 8).md"
KAIZEN_REPORT_DIR="$REPORTS" bash "$WEEKLY" >/dev/null 2>&1
check "weekly.sh runs when the newest report is 8 days old" yes "$(claude_ran)"
rm -f "$SANDBOX/claude.calls" "$REPORTS"/*.md
touch "$REPORTS/$(days_ago 1).md"
KAIZEN_FORCE=1 KAIZEN_REPORT_DIR="$REPORTS" bash "$WEEKLY" >/dev/null 2>&1
check "KAIZEN_FORCE=1 runs regardless of the newest report" yes "$(claude_ran)"

echo "$passed passed, $failed failed"
(( failed == 0 ))
