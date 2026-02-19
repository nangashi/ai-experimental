#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="${PROJECT_ROOT}/.claude/skills"
DEST_DIR="${HOME}/.claude/skills"

list_skills() {
  find "$SRC_DIR" -maxdepth 1 -mindepth 1 -type d -not -name 'old' -printf '%f\n' | sort
}

usage() {
  echo "Usage: $(basename "$0") <skill_name>"
  echo ""
  echo "Available skills:"
  list_skills | sed 's/^/  /'
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

skill_name="$1"
src="${SRC_DIR}/${skill_name}"
dest="${DEST_DIR}/${skill_name}"

if [ "$skill_name" = "old" ]; then
  echo "Error: 'old' is not a deployable skill" >&2
  exit 1
fi

if [ ! -d "$src" ]; then
  echo "Error: skill '${skill_name}' not found in ${SRC_DIR}/" >&2
  echo ""
  echo "Available skills:"
  list_skills | sed 's/^/  /'
  exit 1
fi

if [ -d "$dest" ]; then
  rm -rf "$dest"
  echo "Removed existing: ${dest}"
fi

mkdir -p "$DEST_DIR"
cp -r "$src" "$dest"
echo "Deployed: ${src} -> ${dest}"
