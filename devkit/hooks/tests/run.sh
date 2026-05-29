#!/usr/bin/env bash
# Tiny test harness for hooks/. Feeds canned PreToolUse JSON payloads to a hook
# script and asserts the exit code.
#
# block-dangerous-rm.sh is covered here.
# block-secrets.sh is intentionally NOT covered — it shells out to `git diff
# --cached` against the caller's cwd, so testing it in isolation requires
# building a temp git repo with a staged diff. The shape of its patterns can
# still be eyeballed in the script itself.
#
# Run:   hooks/tests/run.sh
# Exit:  0 if all assertions pass, 1 otherwise.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO}/hooks/block-dangerous-rm.sh"

pass=0
fail=0

assert_exit() {
  local name="$1" cmd="$2" expect="$3"
  local payload actual
  payload=$(jq -n --arg cmd "$cmd" '{tool_input: {command: $cmd}}')
  printf '%s' "$payload" | "$HOOK" >/dev/null 2>&1
  actual=$?
  if [[ "$actual" == "$expect" ]]; then
    printf '  PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s — expected exit %s, got %s (cmd: %s)\n' "$name" "$expect" "$actual" "$cmd"
    fail=$((fail + 1))
  fi
}

echo "block-dangerous-rm.sh:"
# Block cases (exit 2).
assert_exit "rm -rf /"             "rm -rf /"             2
assert_exit "rm -rf ~"             "rm -rf ~"             2
assert_exit "rm -rf ~/"            "rm -rf ~/"            2
assert_exit "rm -rf .."            "rm -rf .."            2
assert_exit "rm -rf ../foo"        "rm -rf ../foo"        2
assert_exit "rm -rf /Users"        "rm -rf /Users"        2
assert_exit "rm -rf /Users/me"     "rm -rf /Users/me"     2
assert_exit "rm -rf \$HOME"        "rm -rf \$HOME"        2
assert_exit "rm -rf \$HOME/x"      "rm -rf \$HOME/x"      2

# Allow cases (exit 0).
assert_exit "rm -rf foo"           "rm -rf foo"           0
assert_exit "rm -rf ./build"       "rm -rf ./build"       0
assert_exit "rm file (no -r)"      "rm file"              0
assert_exit "ls -la (not rm)"      "ls -la"               0
assert_exit "rm -i interactive"    "rm -i foo.txt"        0


echo
echo "block-secrets.sh:"
SECRETS_HOOK="${REPO}/hooks/block-secrets.sh"
TMP_REPO=$(mktemp -d)
(
  cd "$TMP_REPO"
  git init -q
  git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
)

assert_secrets_exit() {
  local name="$1" cmd="$2" file_content="$3" expect="$4" actual
  ( cd "$TMP_REPO" && git reset -q --hard HEAD && rm -f leak.txt removal.txt )
  if [[ -n "$file_content" ]]; then
    printf '%s\n' "$file_content" > "$TMP_REPO/leak.txt"
    ( cd "$TMP_REPO" && git add leak.txt )
  fi
  local payload
  payload=$(jq -n --arg cmd "$cmd" --arg cwd "$TMP_REPO" \
    '{tool_input: {command: $cmd, cwd: $cwd}}')
  printf '%s' "$payload" | "$SECRETS_HOOK" >/dev/null 2>&1
  actual=$?
  if [[ "$actual" == "$expect" ]]; then
    printf '  PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s — expected exit %s, got %s\n' "$name" "$expect" "$actual"
    fail=$((fail + 1))
  fi
}

# Fake secrets are split across adjacent shell strings so the source file
# itself does not match block-secrets.sh's patterns. They concatenate at
# runtime back into the full pattern the regex expects.
# Block cases.
assert_secrets_exit "AWS key in diff"     "git commit -m x" "aws_key=""AKIA""IOSFODNN7EXAMPLE"  2
assert_secrets_exit "GitHub PAT in diff"  "git commit -m x" "token=""ghp_""1234567890123456789012345678901234567890" 2
assert_secrets_exit "private key header"  "git commit -m x" "-----BEGIN RSA ""PRIVATE KEY-----" 2
assert_secrets_exit "Anthropic key"       "git commit -m x" "sk-ant-""abcdefghijklmnopqrstuv"   2

# Allow cases.
assert_secrets_exit "clean diff"          "git commit -m x" "hello world"                       0
assert_secrets_exit "non-commit command"  "git status"      "aws_key=""AKIA""IOSFODNN7EXAMPLE"  0
assert_secrets_exit "commit with no staged" "git commit -m x" ""                                0

# Removing a line that contains a secret-shaped string must NOT block — you
# can't leak a secret by deleting it. Set up a baseline commit that contains
# the secret, then stage a removal.
( cd "$TMP_REPO" && git reset -q --hard HEAD && rm -f leak.txt
  printf 'aws_key=%s%s\n' "AKIA" "IOSFODNN7EXAMPLE" > removal.txt
  git add removal.txt && git -c user.email=t@t -c user.name=t commit -q -m base
  git rm -q removal.txt )
payload=$(jq -n --arg cmd "git commit -m x" --arg cwd "$TMP_REPO" \
  '{tool_input: {command: $cmd, cwd: $cwd}}')
printf '%s' "$payload" | "$SECRETS_HOOK" >/dev/null 2>&1
actual=$?
if [[ "$actual" == 0 ]]; then
  printf '  PASS  %s\n' "removal of secret line is allowed"
  pass=$((pass + 1))
else
  printf '  FAIL  removal of secret line — expected exit 0, got %s\n' "$actual"
  fail=$((fail + 1))
fi

rm -rf "$TMP_REPO"

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" == 0 ]]
