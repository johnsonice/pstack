#!/usr/bin/env bash
# Link this checkout's skills and subagents into the user-level folders that
# Claude Code and Codex read, so an edit in the repo applies at once.
# Idempotent and non-destructive: a real directory or a symlink into another
# repo is skipped, never overwritten. `./install.sh --uninstall` removes only
# the links that point into this checkout.
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Cursor-only skills stay out of other harnesses.
SKIP_SKILLS=(make-bot-ui)
# The universal folder (Codex, OpenCode, and others), then Claude Code's.
SKILL_DIRS=("${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}" "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}")
CLAUDE_AGENTS_DIR="${CLAUDE_AGENTS_DIR:-$HOME/.claude/agents}"

mode="${1:-install}"
case "$mode" in
  install|--uninstall) ;;
  *) echo "usage: $0 [--uninstall]" >&2; exit 2 ;;
esac

linked=0
already=0
skipped=0
removed=0

link_one() { # src dest
  local src="$1" dest="$2"
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      already=$((already + 1))
    else
      echo "! ${dest/#$HOME/~} SKIPPED: symlink points to $(readlink "$dest")"
      skipped=$((skipped + 1))
    fi
  elif [ -e "$dest" ]; then
    echo "! ${dest/#$HOME/~} SKIPPED: a real file or directory is already there"
    skipped=$((skipped + 1))
  else
    ln -s "$src" "$dest"
    echo "+ ${dest/#$HOME/~}"
    linked=$((linked + 1))
  fi
}

unlink_one() { # dest
  local dest="$1"
  [ -L "$dest" ] || return 0
  case "$(readlink "$dest")" in
    "$REPO_DIR"/*)
      rm "$dest"
      echo "- ${dest/#$HOME/~}"
      removed=$((removed + 1))
      ;;
  esac
}

is_skipped() {
  local n
  for n in "${SKIP_SKILLS[@]}"; do
    [ "$n" = "$1" ] && return 0
  done
  return 1
}

for dir in "${SKILL_DIRS[@]}"; do
  mkdir -p "$dir"
  for src in "$REPO_DIR"/skills/*/; do
    src="${src%/}"
    name="$(basename "$src")"
    is_skipped "$name" && continue
    if [ "$mode" = "--uninstall" ]; then
      unlink_one "$dir/$name"
    else
      link_one "$src" "$dir/$name"
    fi
  done
done

mkdir -p "$CLAUDE_AGENTS_DIR"
for src in "$REPO_DIR"/agents/*.md; do
  dest="$CLAUDE_AGENTS_DIR/$(basename "$src")"
  if [ "$mode" = "--uninstall" ]; then
    unlink_one "$dest"
  else
    link_one "$src" "$dest"
  fi
done

echo ""
if [ "$mode" = "--uninstall" ]; then
  echo "Done: $removed links removed."
else
  echo "Done: $linked linked, $already already linked, $skipped skipped."
  if [ "$skipped" -gt 0 ]; then
    echo "Resolve the skipped entries by hand, then re-run this script."
  fi
  echo "Start a new Claude Code or Codex session to pick up new skills."
fi
