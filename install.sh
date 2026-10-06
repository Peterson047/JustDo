#!/usr/bin/env bash
# Installs (or removes) the JustDo! directive and skill across supported tools.
# Compatible with Linux (GNU) and macOS (BSD).
#
# Usage: ./install.sh [--update|--remove] [--no-skill]
#   --update    install or refresh (default)
#   --remove    remove what this script installed
#   --no-skill  handle only the global instructions; skip the skills section
#
# Never overwrites existing configs:
# - Instructions: injects a marker-delimited block and refreshes it on each run.
# - Skills: copies SKILL.md into the skills folder of detected tools.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_AGENTS="$ROOT_DIR/AGENTS.md"
SRC_SKILL="$ROOT_DIR/SKILL.md"
START="<!-- just-do:start -->"
END="<!-- just-do:end -->"

# 1. Global instructions (marker-delimited block injection)
INSTRUCTION_TARGETS=(
  "$HOME/.codex/AGENTS.md"
  "$HOME/.claude/CLAUDE.md"
  "$HOME/.gemini/GEMINI.md"
)

# 2. Global skills (copies SKILL.md)
# Format: "tool_base_dir:skill_target_path"
SKILL_TARGETS=(
  "$HOME/.claude:$HOME/.claude/skills/just-do/SKILL.md"
  "$HOME/.gemini/antigravity-cli:$HOME/.gemini/antigravity-cli/skills/just-do/SKILL.md"
  "$HOME/.agents:$HOME/.agents/skills/just-do/SKILL.md"
  # Unverified path: uncomment after checking the Codex docs.
  # "$HOME/.codex:$HOME/.codex/skills/just-do/SKILL.md"
)

# --- Arguments --------------------------------------------------------------
ACTION=""
INSTALL_SKILL=true
for arg in "$@"; do
  case "$arg" in
    --update|--remove) ACTION="$arg" ;;
    --no-skill) INSTALL_SKILL=false ;;
    *)
      echo "usage: $0 [--update|--remove] [--no-skill]" >&2
      exit 1
      ;;
  esac
done

# True when file $1 exists and contains the literal string $2
has_marker() { [ -f "$1" ] && grep -qF "$2" "$1"; }

# --- Detect an existing installation ----------------------------------------
is_installed=false

for f in "${INSTRUCTION_TARGETS[@]}"; do
  if has_marker "$f" "$START"; then
    is_installed=true
    break
  fi
done

if ! $is_installed && $INSTALL_SKILL; then
  for entry in "${SKILL_TARGETS[@]}"; do
    if [ -f "${entry##*:}" ]; then
      is_installed=true
      break
    fi
  done
fi

# Interactive wizard if already installed and no action was given
if $is_installed && [ -z "$ACTION" ]; then
  if [ -t 0 ]; then
    echo "JustDo!! is already installed in one or more tools."
    echo
    echo "What would you like to do?"
    echo "  1) Update / Reinstall"
    echo "  2) Remove / Uninstall"
    echo "  3) Cancel"
    echo
    read -rp "Select an option [1-3]: " choice
    case "$choice" in
      1) ACTION="--update" ;;
      2) ACTION="--remove" ;;
      *)
        echo "Canceled."
        exit 0
        ;;
    esac
  fi
fi
[ -n "$ACTION" ] || ACTION="--update"

# --- Validate sources before touching anything ------------------------------
if [ "$ACTION" = "--update" ]; then
  if [ ! -f "$SRC_AGENTS" ]; then
    echo "error: $SRC_AGENTS not found" >&2
    exit 1
  fi
  if $INSTALL_SKILL && [ ! -f "$SRC_SKILL" ]; then
    echo "error: $SRC_SKILL not found" >&2
    exit 1
  fi
fi

# --- 1. Global instructions -------------------------------------------------
echo "==> Global instructions"
for f in "${INSTRUCTION_TARGETS[@]}"; do
  if [ ! -d "$(dirname "$f")" ]; then
    echo "skip    $f (tool not found)"
    continue
  fi

  had_block=false
  if has_marker "$f" "$START" && has_marker "$f" "$END"; then
    had_block=true
    # Overwrite in place (cat >) to keep permissions and symlinks intact
    sed "/$START/,/$END/d" "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
  elif has_marker "$f" "$START" || has_marker "$f" "$END"; then
    # A lone marker would make sed delete up to the end of the file
    echo "warn    $f (orphan marker found; fix manually)"
    continue
  fi

  if [ "$ACTION" = "--remove" ]; then
    if $had_block; then
      # If the file is now empty or only whitespace, delete it completely
      if [ -z "$(tr -d '[:space:]' < "$f")" ]; then
        rm -f "$f"
        echo "deleted $f"
      else
        echo "removed block from $f"
      fi
    else
      echo "none    $f"
    fi
    continue
  fi

  # Make sure the existing file ends with a newline before appending
  if [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ]; then echo >> "$f"; fi

  { echo "$START"; cat "$SRC_AGENTS"; echo "$END"; } >> "$f"
  echo "ok      $f"
done

# --- 2. Global skills -------------------------------------------------------
if $INSTALL_SKILL; then
  echo
  echo "==> Global skills"
  for entry in "${SKILL_TARGETS[@]}"; do
    base_dir="${entry%%:*}"
    target_file="${entry##*:}"
    skill_dir="$(dirname "$target_file")"

    if [ ! -d "$base_dir" ]; then
      echo "skip    $target_file (tool not found)"
      continue
    fi

    if [ "$ACTION" = "--remove" ]; then
      if [ -e "$skill_dir" ] || [ -L "$skill_dir" ]; then
        rm -rf "$skill_dir"
        echo "deleted $skill_dir"
      else
        echo "none    $skill_dir"
      fi
      continue
    fi

    # Skip when the target already resolves to the source (e.g. a symlink to the repo)
    if [ -e "$target_file" ] && [ "$SRC_SKILL" -ef "$target_file" ]; then
      echo "same    $target_file (already points to the source)"
      continue
    fi

    mkdir -p "$skill_dir"
    cp "$SRC_SKILL" "$target_file"
    echo "ok      $target_file"
  done
fi