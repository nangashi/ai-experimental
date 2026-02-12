#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
WORK=".task/infinite_update_agent_audit2"
PROMPT_FILE="$WORK/prompt.md"
LOG_FILE="$WORK/run.log"

echo "[$(date -Iseconds)] Loop started" >> "$LOG_FILE"

while true; do
  # STOPフラグチェック（FULLY_CONVERGED時に生成）
  if [ -f "$WORK/STOP" ]; then
    echo "[$(date -Iseconds)] STOP flag detected. All agents fully converged. Exiting loop." | tee -a "$LOG_FILE"
    break
  fi

  echo "[$(date -Iseconds)] --- Starting iteration ---" >> "$LOG_FILE"

  claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"
  exit_code=${PIPESTATUS[0]}

  echo "[$(date -Iseconds)] Iteration completed (exit=$exit_code)" >> "$LOG_FILE"

  if [ $exit_code -ne 0 ]; then
    echo "[$(date -Iseconds)] ERROR: claude exited with code $exit_code. Waiting 30s before retry." >> "$LOG_FILE"
    sleep 30
  fi

  # Brief pause between iterations
  sleep 3
done

echo "[$(date -Iseconds)] Loop finished. Review improvements: $WORK/history.md" | tee -a "$LOG_FILE"
