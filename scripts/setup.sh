#!/usr/bin/env bash
# Idempotent per-machine setup for the Flatline harness. Safe to re-run.
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
HARNESS="$(dirname "$KIT")"
DEV="$(dirname "$HARNESS")"
CL="$HOME/.claude"
mkdir -p "$CL/skills" "$CL/agents" "$CL/commands"

link() { # link <target> <linkpath>
  if [ -L "$2" ]; then ln -sfn "$1" "$2"
  elif [ -e "$2" ]; then echo "skip (exists, not a symlink): $2"; return
  else ln -s "$1" "$2"; fi
  echo "linked $2"
}

for s in "$KIT"/skills/*/; do link "${s%/}" "$CL/skills/$(basename "$s")"; done
for a in "$KIT"/agents/*.md;   do link "$a" "$CL/agents/$(basename "$a")"; done
for c in "$KIT"/commands/*.md; do link "$c" "$CL/commands/$(basename "$c")"; done

# Personal memory repo is optional (never shared) — link it only if present.
if [ -d "$HARNESS/memory" ]; then
  for s in "$HARNESS"/memory/skills/*/; do link "${s%/}" "$CL/skills/$(basename "$s")"; done
  for c in "$HARNESS"/memory/commands/*.md; do link "$c" "$CL/commands/$(basename "$c")"; done
fi

# Root CLAUDE.md so every client repo under ~/Developer inherits the conventions.
if [ -e "$DEV/CLAUDE.md" ] && [ ! -L "$DEV/CLAUDE.md" ]; then
  mv "$DEV/CLAUDE.md" "$DEV/CLAUDE.md.bak" && echo "backed up old CLAUDE.md -> CLAUDE.md.bak"
fi
link "$KIT/templates/Developer-CLAUDE.md" "$DEV/CLAUDE.md"

# Enforce guardrails on commits to the kit.
git -C "$KIT" config core.hooksPath scripts/hooks && echo "git hooks enabled (lint + index check)"

# `dev <name>` shell shortcut.
LINE="source \"$KIT/scripts/dev.zsh\"   # flatline harness: dev <repo>"
grep -qF "scripts/dev.zsh" "$HOME/.zshrc" 2>/dev/null || { echo "$LINE" >> "$HOME/.zshrc"; echo "added dev shortcut to ~/.zshrc"; }

python3 "$KIT/scripts/kb.py" lint
echo "Harness ready. Open a new shell to use: dev <repo>"
