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

# Succeed when the project the file lives in (searched up to its repo root) declares the
# formatter: a config file, a pyproject/package.json section, or a local install. A formatter
# that is merely on PATH must not rewrite files in projects that never adopted it: on an
# unformatted file it would reformat every untouched line.
project_uses() {
  local dir="$1" name="$2"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    case "$name" in
      ruff)
        [[ -f "$dir/ruff.toml" || -f "$dir/.ruff.toml" || -x "$dir/.venv/bin/ruff" ]] && return 0
        [[ -f "$dir/pyproject.toml" ]] && grep -q '^\[tool\.ruff' "$dir/pyproject.toml" && return 0 ;;
      black)
        [[ -x "$dir/.venv/bin/black" ]] && return 0
        [[ -f "$dir/pyproject.toml" ]] && grep -q '^\[tool\.black' "$dir/pyproject.toml" && return 0 ;;
      prettier)
        [[ -x "$dir/node_modules/.bin/prettier" ]] && return 0
        compgen -G "$dir/.prettierrc*" >/dev/null || compgen -G "$dir/prettier.config.*" >/dev/null && return 0 ;;
      biome)
        [[ -f "$dir/biome.json" || -f "$dir/biome.jsonc" ]] && return 0 ;;
      shfmt)
        [[ -f "$dir/.editorconfig" ]] && grep -q 'shell_variant\|\[\*\.sh\]' "$dir/.editorconfig" && return 0 ;;
    esac
    [[ -e "$dir/.git" ]] && return 1
    dir="$(dirname "$dir")"
  done
  return 1
}

format_one() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local dir bin
  dir="$(dirname "$file")"

  case "$file" in
    *.py)
      if project_uses "$dir" ruff && bin="$(resolve_bin "$dir" ruff)"; then
        "$bin" format -- "$file" >/dev/null 2>&1 || return 0
      elif project_uses "$dir" black && bin="$(resolve_bin "$dir" black)"; then
        "$bin" -q -- "$file" >/dev/null 2>&1 || return 0
      fi
      ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.jsonc|*.css|*.scss|*.html|*.md|*.svelte|*.vue|*.yaml|*.yml)
      if project_uses "$dir" prettier && bin="$(resolve_bin "$dir" prettier)"; then
        "$bin" --write --log-level=silent "$file" >/dev/null 2>&1 || return 0
      elif project_uses "$dir" biome && bin="$(resolve_bin "$dir" biome)"; then
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
      project_uses "$dir" shfmt && bin="$(resolve_bin "$dir" shfmt)" && "$bin" -w -- "$file" >/dev/null 2>&1 || return 0
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
