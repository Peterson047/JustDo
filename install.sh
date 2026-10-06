#!/usr/bin/env bash
# Installs (or removes, with --remove) the JustDo directive and skill across supported tools.
# Fully compatible with Linux (GNU) and macOS (BSD).
# Does not overwrite existing configurations:
# - Instructions: injects marker-delimited block and updates it on subsequent runs.
# - Skills: copies SKILL.md to the skills folder of detected tools.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_AGENTS="$ROOT_DIR/AGENTS.MD"
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
)

# Check if JustDo is currently installed in any target
is_installed=false

for f in "${INSTRUCTION_TARGETS[@]}"; do
  if [ -f "$f" ] && grep -qF "$START" "$f" 2>/dev/null; then
    is_installed=true
    break
  fi
done

if ! $is_installed; then
  for entry in "${SKILL_TARGETS[@]}"; do
    target_file="${entry##*:}"
    if [ -f "$target_file" ]; then
      is_installed=true
      break
    fi
  done
fi

ACTION="${1:-}"

# Interactive wizard if already installed and no argument was provided
if $is_installed && [ -z "$ACTION" ]; then
  if [ -t 0 ]; then
    echo "JustDo is already installed in one or more tools."
    echo
    echo "What would you like to do?"
    echo "  1) Update / Reinstall"
    echo "  2) Remove / Uninstall"
    echo "  3) Cancel"
    echo
    read -rp "Select an option [1-3]: " choice
    case "$choice" in
      1)
        ACTION="--update"
        ;;
      2)
        ACTION="--remove"
        ;;
      *)
        echo "Canceled."
        exit 0
        ;;
    esac
  else
    ACTION="--update"
  fi
fi

echo "==> Global instructions"
for f in "${INSTRUCTION_TARGETS[@]}"; do
  if [ ! -d "$(dirname "$f")" ]; then
    echo "skip    $f (tool not found)"
    continue
  fi

  had_block=false
  if [ -f "$f" ] && grep -qF "$START" "$f"; then
    had_block=true
    # Portable across GNU and BSD sed: write to temporary file and move
    sed "/$START/,/$END/d" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi

  if [ "$ACTION" = "--remove" ]; then
    if $had_block; then
      # If the file is now empty or contains only whitespace, delete the file completely
      if [ -f "$f" ] && [ -z "$(tr -d '[:space:]' < "$f")" ]; then
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

  if [ -s "$f" ] && [ -n "$(tail -c 1 "$f" 2>/dev/null)" ]; then echo >> "$f"; fi

  { echo "$START"; cat "$SRC_AGENTS"; echo "$END"; } >> "$f"
  echo "ok      $f"
done

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
    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
      rm -rf "$skill_dir"
      echo "deleted $target_file"
    else
      echo "none    $target_file"
    fi
    continue
  fi

  mkdir -p "$skill_dir"
  cp "$SRC_SKILL" "$target_file"
  echo "ok      $target_file"
done