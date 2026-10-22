#!/usr/bin/env sh
# Agent Skills live in .agents/skills (canonical, harness-neutral; OpenCode reads it directly).
# Copy them to folders that specific harnesses require. Add a line per harness as needed.
set -eu
cd "$(dirname "$0")/.."
for dest in .claude/skills; do
  mkdir -p "$dest"
  cp -R .agents/skills/. "$dest/"
done
