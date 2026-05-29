#!/usr/bin/env bash
# PostToolUse hook — auto-format files Claude just edited or wrote.
#
# Reads the hook payload from stdin (JSON via the harness), extracts the
# edited file path, and runs a language-appropriate formatter if one is
# available on PATH. Silent on success; logs to stderr on failure but never
# blocks the turn.
#
# Toggle off with CLAUDE_AUTOFORMAT=false in env or settings.json.

[[ "${CLAUDE_AUTOFORMAT:-true}" != "true" ]] && exit 0

# Slurp stdin (hook payload is a single JSON object).
payload="$(cat 2>/dev/null || true)"
[[ -z "$payload" ]] && exit 0

# Need jq to parse the payload reliably; degrade gracefully if missing.
command -v jq >/dev/null 2>&1 || exit 0

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
case "$tool_name" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Collect file paths. Edit/Write expose `file_path`; MultiEdit exposes
# `edits[].file_path` or a top-level `file_path` depending on the schema.
# Portable to bash 3.2 (macOS) — no mapfile.
files_raw="$(
  printf '%s' "$payload" | jq -r '
    [
      .tool_input.file_path? // empty,
      (.tool_input.edits? // [] | .[].file_path? // empty),
      .tool_input.notebook_path? // empty
    ] | .[] | select(. != null and . != "")
  ' | awk '!seen[$0]++'
)"

[[ -z "$files_raw" ]] && exit 0

# Walk up from a file's directory looking for a binary inside a local
# tooling dir (node_modules/.bin or .venv/bin). Echoes path on hit.
find_local_bin() {
  local start_dir="$1" bin_name="$2"
  local dir="$start_dir"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -x "$dir/node_modules/.bin/$bin_name" ]]; then
      echo "$dir/node_modules/.bin/$bin_name"
      return 0
    fi
    if [[ -x "$dir/.venv/bin/$bin_name" ]]; then
      echo "$dir/.venv/bin/$bin_name"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# Resolve a formatter: prefer a project-local install over PATH.
resolve_bin() {
  local file_dir="$1" name="$2" local_path
  local_path="$(find_local_bin "$file_dir" "$name")" && { echo "$local_path"; return 0; }
  command -v "$name" >/dev/null 2>&1 && { echo "$name"; return 0; }
  return 1
}

format_one() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local dir bin
  dir="$(dirname "$file")"

  case "$file" in
    *.py)
      if bin="$(resolve_bin "$dir" ruff)"; then
        "$bin" format -- "$file" >/dev/null 2>&1 || return 0
      elif bin="$(resolve_bin "$dir" black)"; then
        "$bin" -q -- "$file" >/dev/null 2>&1 || return 0
      fi
      ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.jsonc|*.css|*.scss|*.html|*.md|*.svelte|*.vue|*.yaml|*.yml)
      if bin="$(resolve_bin "$dir" prettier)"; then
        "$bin" --write --log-level=silent "$file" >/dev/null 2>&1 || return 0
      elif bin="$(resolve_bin "$dir" biome)"; then
        "$bin" format --write "$file" >/dev/null 2>&1 || return 0
      fi
      ;;
    *.rs)
      bin="$(resolve_bin "$dir" rustfmt)" && "$bin" --quiet -- "$file" >/dev/null 2>&1 || return 0
      ;;
    *.go)
      bin="$(resolve_bin "$dir" gofmt)" && "$bin" -w -- "$file" >/dev/null 2>&1 || return 0
      ;;
    *.sh|*.bash)
      bin="$(resolve_bin "$dir" shfmt)" && "$bin" -w -- "$file" >/dev/null 2>&1 || return 0
      ;;
    *)
      return 0
      ;;
  esac
}

while IFS= read -r f; do
  [[ -n "$f" ]] && format_one "$f"
done <<< "$files_raw"

exit 0
