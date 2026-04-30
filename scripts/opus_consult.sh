#!/usr/bin/env bash
set -euo pipefail

MODEL="claude-opus-4-7"
EFFORT="medium"
BUDGET="20"
PROMPT_FILE=""
SESSION_FILE=""
BARE=0
DRY_RUN=0
READ_ONLY=0
READ_DIRS=()
RUN_DIR=""
PROMPT_FROM_STDIN=0
PROMPT_TEXT=""

cleanup() {
  [[ -n "$RUN_DIR" && -d "$RUN_DIR" ]] && rm -rf "$RUN_DIR"
  return 0
}
trap cleanup EXIT
trap 'trap - EXIT; cleanup; exit 129' HUP
trap 'trap - EXIT; cleanup; exit 130' INT
trap 'trap - EXIT; cleanup; exit 143' TERM

usage() {
  cat <<'USAGE'
Usage: opus_consult.sh [--prompt-file PATH] [--session-file PATH] [--effort low|medium|high|xhigh|max] [--budget USD] [--read-only] [--read-dir PATH] [--bare] [--dry-run]

Reads prompt from --prompt-file or stdin. Calls Claude Code Opus 4.7 with tools disabled by
default, JSON output, and a default $20 runaway-spend cap. Add --read-only plus one or more
--read-dir PATH values to allow Claude read/search/list access only (Read, Glob, Grep, LS)
inside those directories. One-shot calls disable session persistence. Threaded calls use
--session-file to keep a bounded resumable Opus conversation. Default auth is the existing
Claude Code login. Use --bare only for strict API-key mode. Stdin prompts are kept in memory
instead of a temp file; use --prompt-file for large prompts. Dry run prints the command only.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file)
      PROMPT_FILE="${2:-}"
      shift 2
      ;;
    --session-file)
      SESSION_FILE="${2:-}"
      shift 2
      ;;
    --effort)
      EFFORT="${2:-}"
      shift 2
      ;;
    --budget)
      BUDGET="${2:-}"
      shift 2
      ;;
    --bare)
      BARE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --read-only)
      READ_ONLY=1
      shift
      ;;
    --read-dir)
      READ_ONLY=1
      read_dir="${2:-}"
      if [[ "$read_dir" == "" ]]; then
        echo "--read-dir requires a path" >&2
        exit 2
      fi
      READ_DIRS+=("$read_dir")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$EFFORT" in
  low|medium|high|xhigh|max) ;;
  *)
    echo "Invalid --effort: $EFFORT" >&2
    exit 2
    ;;
esac

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code CLI not found on PATH" >&2
  exit 127
fi

if [[ "$BARE" == "1" && "$DRY_RUN" == "0" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "Strict --bare mode requires ANTHROPIC_API_KEY because it disables OAuth/keychain auth." >&2
  echo "Omit --bare to use the existing Claude Code login." >&2
  exit 3
fi

if [[ "$PROMPT_FILE" == "" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "--dry-run requires --prompt-file because stdin prompts have no reusable path" >&2
    exit 2
  fi
  PROMPT_FROM_STDIN=1
  stdin_with_sentinel="$(cat; printf .)"
  PROMPT_TEXT="${stdin_with_sentinel%.}"
  unset stdin_with_sentinel
elif [[ "$PROMPT_FILE" != /* ]]; then
  PROMPT_FILE="$(pwd)/$PROMPT_FILE"
fi

if [[ "$SESSION_FILE" != "" && "$SESSION_FILE" != /* ]]; then
  SESSION_FILE="$(pwd)/$SESSION_FILE"
fi

if [[ "$READ_ONLY" == "1" && ${#READ_DIRS[@]} -eq 0 ]]; then
  echo "--read-only requires at least one --read-dir PATH so read scope is explicit" >&2
  exit 2
fi

for i in "${!READ_DIRS[@]}"; do
  if [[ "${READ_DIRS[$i]}" != /* ]]; then
    READ_DIRS[$i]="$(pwd)/${READ_DIRS[$i]}"
  fi
  if [[ ! -d "${READ_DIRS[$i]}" ]]; then
    echo "--read-dir is not a directory: ${READ_DIRS[$i]}" >&2
    exit 2
  fi
done

if [[ "$SESSION_FILE" != "" && -s "$SESSION_FILE" ]]; then
  session_id="$(tr -d '\n\r[:space:]' < "$SESSION_FILE")"
  if [[ ! "$session_id" =~ ^[0-9A-Za-z_-]+$ ]]; then
    echo "Invalid session id in $SESSION_FILE" >&2
    exit 2
  fi
fi

if [[ "$PROMPT_FROM_STDIN" == "1" ]]; then
  if [[ "$PROMPT_TEXT" == "" ]]; then
    echo "Prompt from stdin is empty" >&2
    exit 2
  fi
elif [[ ! -s "$PROMPT_FILE" ]]; then
  echo "Prompt file is empty: $PROMPT_FILE" >&2
  exit 2
fi

if [[ "$DRY_RUN" == "0" ]]; then
  RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opus-consult-run.XXXXXX")"
else
  RUN_DIR="\${TMPDIR:-/tmp}/opus-consult-run.XXXXXX"
fi

cmd=(claude -p --model "$MODEL" --effort "$EFFORT")
if [[ "$BARE" == "1" ]]; then
  cmd+=(--bare)
fi
if [[ "$READ_ONLY" == "1" ]]; then
  cmd+=(--tools "Read,Glob,Grep,LS")
  for read_dir in "${READ_DIRS[@]}"; do
    cmd+=(--add-dir "$read_dir")
  done
else
  cmd+=(--tools "")
fi
cmd+=(--max-budget-usd "$BUDGET" --output-format json)
if [[ "$SESSION_FILE" == "" ]]; then
  cmd+=(--no-session-persistence)
fi
if [[ "$SESSION_FILE" != "" && -s "$SESSION_FILE" ]]; then
  cmd+=(--resume "$session_id" --fork-session)
fi

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opus-consult-run.XXXXXX")"\n'
  printf 'cd "$RUN_DIR" &&'
  printf ' %q' "${cmd[@]}"
  printf ' < %q\n' "$PROMPT_FILE"
  exit 0
fi

if [[ "$PROMPT_FROM_STDIN" == "1" ]]; then
  json="$(
    cd "$RUN_DIR"
    printf '%s' "$PROMPT_TEXT" | "${cmd[@]}"
  )"
else
  json="$(
    cd "$RUN_DIR"
    "${cmd[@]}" < "$PROMPT_FILE"
  )"
fi

READ_DIRS_TEXT="$(printf "%s\n" "${READ_DIRS[@]}")"
printf '%s\n' "$json" | OPUS_CONSULT_MODEL="$MODEL" OPUS_CONSULT_BUDGET="$BUDGET" OPUS_CONSULT_SESSION_FILE="$SESSION_FILE" OPUS_CONSULT_READ_ONLY="$READ_ONLY" OPUS_CONSULT_READ_DIRS="$READ_DIRS_TEXT" python3 -c '
import json
import os
import sys
import tempfile

data = json.load(sys.stdin)
usage = data.get("usage") or {}
model_usage = data.get("modelUsage") or {}
target_model = os.environ.get("OPUS_CONSULT_MODEL", "")
budget = float(os.environ.get("OPUS_CONSULT_BUDGET", "0") or 0)
session_file = os.environ.get("OPUS_CONSULT_SESSION_FILE", "")
read_only = os.environ.get("OPUS_CONSULT_READ_ONLY", "0") == "1"
read_dirs = [line for line in os.environ.get("OPUS_CONSULT_READ_DIRS", "").splitlines() if line]
total_cost = data.get("total_cost_usd")
exit_code = 0
model_ok = not target_model or target_model in model_usage

print("OPUS_CONSULT_RESULT")
print("is_error:", data.get("is_error"))
if data.get("api_error_status"):
    print("api_error_status:", data.get("api_error_status"))
print("read_only_tools:", read_only)
if read_dirs:
    print("read_dirs:", json.dumps(read_dirs, sort_keys=True))
print("duration_ms:", data.get("duration_ms"))
print("total_cost_usd:", data.get("total_cost_usd"))
print("usage:", json.dumps(usage, sort_keys=True))
print("modelUsage:", json.dumps(model_usage, sort_keys=True))
print("result:")
print(data.get("result", ""))

if not model_ok:
    print(f"error: expected model {target_model} not found in modelUsage", file=sys.stderr)
    exit_code = 4

if session_file and not data.get("is_error") and model_ok:
    session_id = data.get("session_id") or ""
    if session_id:
        session_dir = os.path.dirname(session_file) or "."
        os.makedirs(session_dir, exist_ok=True)
        tmp_path = None
        try:
            fd, tmp_path = tempfile.mkstemp(prefix=".opus-consult-", dir=session_dir)
            with os.fdopen(fd, "w") as tmp:
                tmp.write(session_id + "\n")
            os.replace(tmp_path, session_file)
            tmp_path = None
        finally:
            if tmp_path:
                try:
                    os.unlink(tmp_path)
                except FileNotFoundError:
                    pass
    else:
        print("warning: no session_id in Claude JSON; existing session file left unchanged", file=sys.stderr)
elif session_file and not model_ok:
    print("warning: session file left unchanged because expected model was not confirmed", file=sys.stderr)

if total_cost is not None and budget and float(total_cost) > budget:
    print(f"warning: total_cost_usd {total_cost} exceeded budget cap {budget}", file=sys.stderr)

if data.get("is_error"):
    exit_code = max(exit_code, 1)

sys.exit(exit_code)
'
