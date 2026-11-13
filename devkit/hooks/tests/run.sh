#!/usr/bin/env bash
# Tests for the devkit hooks. Each case feeds a hook event on stdin and checks the exit
# code (0 = allow, 2 = block) or the file the hook left behind.
#
# Run:   hooks/tests/run.sh
# Exit:  0 if all assertions pass, 1 otherwise.

set -u

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
pass=0
fail=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1))
  else
    printf '  FAIL  %s: expected %s, got %s\n' "$name" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

echo "block-dangerous-rm.py:"
FAKE_HOME=/Users/tester
WORK_DIR="$FAKE_HOME/project"

rm_exit() {
  local command="$1" cwd="${2:-$WORK_DIR}"
  jq -n --arg command "$command" --arg cwd "$cwd" '{cwd: $cwd, tool_input: {command: $command}}' \
    | env -u UNSET_BUILD_DIR HOME="$FAKE_HOME" python3 "$HOOKS/block-dangerous-rm.py" >/dev/null 2>&1
  echo $?
}

while IFS= read -r command; do
  [[ -n "$command" ]] && check "blocks: $command" 2 "$(rm_exit "$command")"
done <<'BLOCKED'
rm -rf /
rm -rf ~
rm -rf ~/
rm -rf ..
rm -rf ../foo
rm -rf /Users
rm -rf /Users/me
rm -rf $HOME
rm -rf $HOME/x
rm -rf "$HOME"
rm -rf '/'
rm -rf build ~
rm -rf ./build /
rm --recursive /etc
rm -r -f /usr
rm -fr /tmp
rm -rf -- /
sudo rm -rf /
rm -rf ~/*
rm -rf ~/Documents
rm -rf ~/Documents/*
rm -rf "$UNSET_BUILD_DIR/"
rm -rf $UNSET_BUILD_DIR/*
cd / && rm -rf etc
echo cleaning; rm -rf ~
ls $(rm -rf ~)
BLOCKED
check "blocks: rm on a later line" 2 "$(rm_exit $'echo start\nrm -rf ~')"
check "blocks: a relative path from the home directory" 2 "$(rm_exit 'rm -rf Documents' "$FAKE_HOME")"

while IFS= read -r command; do
  [[ -n "$command" ]] && check "allows: $command" 0 "$(rm_exit "$command")"
done <<'ALLOWED'
rm -rf foo
rm -rf ./build
rm file
ls -la
rm -i foo.txt
rm -rf /Users/tester/project/build
rm -rf ~/project/node_modules
rm -rf /tmp/scratch-123
rm -rf "${UNSET_BUILD_DIR:?}/"
rm -rf "$UNSET_BUILD_DIR"
rm -rf *.pyc
rm -rf build/*
for dir in api web; do rm -rf "$dir/node_modules"; done
tmp=$(mktemp -d); make -C "$tmp"; rm -rf "$tmp"/*
while read -r name; do rm -rf "$name/cache"; done < packages.txt
git commit -m "rm -rf / is how you lose a disk"
grep -rn "rm -rf" docs
ALLOWED

echo "block-secrets.py:"
REPO="$SANDBOX/repo"
OTHER_DIR="$SANDBOX/elsewhere"
mkdir -p "$REPO" "$OTHER_DIR"
commit_as_tester() { git -C "$REPO" -c user.email=t@t -c user.name=t commit -q "$@"; }
git -C "$REPO" init -q
printf 'tracked\n' > "$REPO/tracked.txt"
git -C "$REPO" add tracked.txt
commit_as_tester -m init

# Fake secrets are split across adjacent strings so this file does not match the patterns.
AWS_KEY="AKIA""IOSFODNN7EXAMPLE"
GITHUB_TOKEN="ghp_""1234567890123456789012345678901234567890"
ANTHROPIC_KEY="sk-ant-""abcdefghijklmnopqrstuv"
OPENAI_PROJECT_KEY="sk-proj-""abcdefghijklmnopqrstuvwxyz012345"
PRIVATE_KEY_HEADER="-----BEGIN RSA ""PRIVATE KEY-----"

reset_repo() {
  git -C "$REPO" reset -q --hard HEAD
  git -C "$REPO" clean -qfd
}

stage() {
  reset_repo
  printf '%s\n' "$1" > "$REPO/leak.txt"
  git -C "$REPO" add leak.txt
}

secrets_exit() {
  local command="$1" cwd="${2:-$REPO}"
  jq -n --arg command "$command" --arg cwd "$cwd" '{cwd: $cwd, tool_input: {command: $command}}' \
    | python3 "$HOOKS/block-secrets.py" 2>"$SANDBOX/stderr" >/dev/null
  echo $?
}

stage "aws_key=$AWS_KEY"
check "AWS key in the staged diff" 2 "$(secrets_exit 'git commit -m x')"
check "the report names the file" 1 "$(grep -c 'leak.txt: AWS access key id' "$SANDBOX/stderr")"
check "the report never repeats the secret" 0 "$(grep -c "$AWS_KEY" "$SANDBOX/stderr")"
check "a non-commit command passes" 0 "$(secrets_exit 'git status')"
check "a commit reached through cd is scanned in that repo" 2 \
  "$(secrets_exit "cd $REPO && git commit -m x" "$OTHER_DIR")"
check "a commit reached through git -C is scanned in that repo" 2 \
  "$(secrets_exit "git -C $REPO commit -m x" "$OTHER_DIR")"
check "a commit in another repo is not blamed for this one" 0 \
  "$(secrets_exit 'git commit -m x' "$OTHER_DIR")"

stage "token=$GITHUB_TOKEN"
check "GitHub token" 2 "$(secrets_exit 'git commit -m x')"
stage "$PRIVATE_KEY_HEADER"
check "private key header" 2 "$(secrets_exit 'git commit -m x')"
stage "$ANTHROPIC_KEY"
check "Anthropic key" 2 "$(secrets_exit 'git commit -m x')"
stage "OPENAI_API_KEY=$OPENAI_PROJECT_KEY"
check "OpenAI project key" 2 "$(secrets_exit 'git commit -m x')"

stage "hello world"
check "a clean diff passes" 0 "$(secrets_exit 'git commit -m x')"
stage "aws_secret_access_key = os.environ['AWS_SECRET_ACCESS_KEY']"
check "reading a secret from the environment passes" 0 "$(secrets_exit 'git commit -m x')"
stage "fixture = '$AWS_KEY'  # pragma: allowlist secret"
check "an allowlisted fixture line passes" 0 "$(secrets_exit 'git commit -m x')"
reset_repo
check "a commit with nothing staged passes" 0 "$(secrets_exit 'git commit -m x')"

reset_repo
printf 'aws_key=%s\n' "$AWS_KEY" >> "$REPO/tracked.txt"
check "an unstaged secret is ignored by a plain commit" 0 "$(secrets_exit 'git commit -m x')"
check "git commit -a scans unstaged changes" 2 "$(secrets_exit 'git commit -am x')"
check "git commit --all scans unstaged changes" 2 "$(secrets_exit 'git commit --all -m x')"

# The hook runs before the command, so `git add x && git commit` has nothing staged yet.
check "git add of a changed file, then commit, is scanned" 2 \
  "$(secrets_exit 'git add tracked.txt && git commit -m x')"
reset_repo
printf 'aws_key=%s\n' "$AWS_KEY" > "$REPO/new-file.txt"
check "an untracked secret is ignored by a plain commit" 0 "$(secrets_exit 'git commit -m x')"
check "git add of a new file, then commit, is scanned" 2 \
  "$(secrets_exit 'git add new-file.txt && git commit -m x')"
check "the report names the new file" 1 "$(grep -c 'new-file.txt: AWS access key id' "$SANDBOX/stderr")"
check "git add . then commit is scanned" 2 "$(secrets_exit 'git add . && git commit -m x')"
check "git add -A then commit is scanned" 2 "$(secrets_exit 'git add -A && git commit -m x')"
check "adding one file does not blame another that stays untracked" 0 \
  "$(secrets_exit 'git add tracked.txt && git commit -m x')"
reset_repo
printf 'aws_key=%s\n' "$AWS_KEY" >> "$REPO/tracked.txt"

# Removing a line that holds a secret cannot leak it.
git -C "$REPO" add tracked.txt
commit_as_tester -m "base with a secret" --no-verify
printf 'tracked\n' > "$REPO/tracked.txt"
git -C "$REPO" add tracked.txt
check "removing a secret line passes" 0 "$(secrets_exit 'git commit -m x')"

echo "auto-format.sh:"
# auto-format only touches files in projects that declare the formatter.
formatted() {
  local config="$1" project
  project=$(mktemp -d "$SANDBOX/format.XXXXXX")
  mkdir -p "$project/.git"
  [[ -n "$config" ]] && printf '%b' "$config" > "$project/pyproject.toml"
  printf 'x = {  "a":1 }\n' > "$project/sample.py"
  jq -n --arg path "$project/sample.py" '{tool_name: "Edit", tool_input: {file_path: $path}}' \
    | bash "$HOOKS/auto-format.sh"
  cat "$project/sample.py"
}

if command -v ruff >/dev/null; then
  check "ruff runs in a project that configures it" 'x = {"a": 1}' \
    "$(formatted '[tool.ruff]\nline-length = 100\n')"
  check "ruff leaves a project without ruff config alone" 'x = {  "a":1 }' "$(formatted '')"
else
  echo "  SKIP  auto-format cases: ruff is not on PATH"
fi

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" == 0 ]]
