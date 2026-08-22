#!/usr/bin/env bash
# PreToolUse / Bash — blocks `git commit` when HEAD is on main or master.
# Portable by design: no machine paths, no repo names, no GitHub org (D18).
# The hook receives the SESSION cwd, not the target of a `cd` inside the command,
# so the repo is resolved from the command itself first, with .cwd as the fallback.

command -v jq  >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

INPUT=$(cat)
[ "$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')" = "Bash" ] || exit 0

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
printf '%s' "$COMMAND" | grep -qE '(^|[;&|]|&&)[[:space:]]*git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit([[:space:]]|$)' || exit 0

SESSION_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')

GITC=$(printf '%s' "$COMMAND" | sed -n 's/.*git[[:space:]]\{1,\}-C[[:space:]]\{1,\}"\{0,1\}\([^"[:space:]]*\)"\{0,1\}.*/\1/p' | head -1)
CDP=$(printf  '%s' "$COMMAND" | sed -n 's/^[[:space:]]*cd[[:space:]]\{1,\}\(.*\)&&.*/\1/p'  | head -1 | sed 's/[[:space:]]*$//; s/^"//; s/"$//')

REPO=""
for cand in "$GITC" "$CDP" "$SESSION_CWD"; do
  [ -n "$cand" ] || continue
  case "$cand" in /*) : ;; *) cand="${SESSION_CWD%/}/$cand" ;; esac
  [ -d "$cand" ] || continue
  top=$(git -C "$cand" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$top" ]; then REPO="$top"; break; fi
done
[ -n "$REPO" ] || exit 0

BRANCH=$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
case "$BRANCH" in main|master) ;; *) exit 0 ;; esac

REASON="Direct commits to '$BRANCH' are blocked in $(basename "$REPO"). Branch first: git -C '$REPO' checkout -b <type>/<short-description>, commit there, push with -u, open a PR."
jq -nc --arg r "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r},continue:true}'
exit 0
