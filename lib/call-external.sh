#!/usr/bin/env bash
# call-external.sh — call the OPPOSITE agent for adversarial review.
#
# Cross-host principle: "the partner reviews, never the host"
#   host=claude → external=codex (via official plugin if available, else codex exec)
#   host=codex  → external=claude (via claude -p with opus xhigh)
#
# Stdin:  the prompt to send to the external reviewer (multi-line OK)
# Stdout: external reviewer's analysis in markdown
# Stderr: operational logs (which external was used, latency, fallback chain)
# Exit:
#   0   external reviewer succeeded
#   2   degraded mode — all externals failed, host-self analysis with banner
#   1   error (recursion detected, missing input, etc.)
#
# Env vars consumed:
#   ADVERSARIAL_REVIEW_HOST          override host detection (passed to detect-host.sh)
#   ADVERSARIAL_REVIEW_DEPTH         anti-recursion counter; refuse if ≥ 1
#   ADVERSARIAL_REVIEW_TIMEOUT       seconds; default 300
#   ADVERSARIAL_REVIEW_FORCE_DEGRADED  if "1", skip externals and go straight to degraded
#                                      (for non-destructive smoke tests)
#
# This script is HOST-AGNOSTIC: detects host at runtime, picks the partner.

set -u

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT="${ADVERSARIAL_REVIEW_TIMEOUT:-300}"
DEPTH="${ADVERSARIAL_REVIEW_DEPTH:-0}"

log() { printf '[call-external] %s\n' "$*" >&2; }

# 1. Anti-recursion: if a parent already invoked us, refuse.
if [ "$DEPTH" -ge 1 ]; then
  log "ERROR: ADVERSARIAL_REVIEW_DEPTH=$DEPTH (≥1) — recursion detected, refusing"
  log "       chain: a parent invocation is already running adversarial review"
  exit 1
fi

# 2. Read prompt from stdin
prompt="$(cat)"
if [ -z "$prompt" ]; then
  log "ERROR: empty prompt on stdin"
  exit 1
fi

# 3. Forced-degraded short-circuit (non-destructive smoke test)
if [ "${ADVERSARIAL_REVIEW_FORCE_DEGRADED:-}" = "1" ]; then
  log "ADVERSARIAL_REVIEW_FORCE_DEGRADED=1 — skipping externals, emitting degraded banner"
  printf '⚠️  DEGRADED MODE — externals skipped (FORCE_DEGRADED=1)\n\n'
  printf 'Host-self analysis (the host is reviewing its own work — violates cross-host principle):\n\n'
  printf '%s\n' "$prompt"
  exit 2
fi

# 4. Detect host
HOST="$(bash "$LIB_DIR/detect-host.sh" || echo unknown)"
log "host=$HOST  depth=$DEPTH  timeout=${TIMEOUT}s"

# 5. Route to opposite partner
case "$HOST" in
  claude)
    # Try Codex via official plugin first (if installed), else codex exec direct
    if claude plugin list 2>/dev/null | grep -q "codex@openai-codex"; then
      log "primary: codex via /codex:adversarial-review (official plugin detected)"
      log "         NOTE: slash invocation requires interactive Claude session;"
      log "         falling back to codex exec for unattended use"
    fi
    if command -v codex >/dev/null 2>&1; then
      log "calling: codex exec --sandbox read-only (DEPTH=$((DEPTH+1)))"
      if ADVERSARIAL_REVIEW_DEPTH=$((DEPTH+1)) \
         codex exec --sandbox read-only --skip-git-repo-check "$prompt" \
         2>>/tmp/call-external-codex.err; then
        exit 0
      fi
      log "codex exec failed; trying gemini cascade"
    else
      log "codex CLI not found; trying gemini cascade"
    fi
    ;;
  codex)
    # Call Claude Opus
    if command -v claude >/dev/null 2>&1; then
      log "calling: claude -p --model opus --effort xhigh (DEPTH=$((DEPTH+1)))"
      if ADVERSARIAL_REVIEW_DEPTH=$((DEPTH+1)) \
         claude -p --model opus --effort xhigh --dangerously-skip-permissions "$prompt" \
         2>>/tmp/call-external-claude.err; then
        exit 0
      fi
      log "claude -p failed; trying gemini cascade"
    else
      log "claude CLI not found; trying gemini cascade"
    fi
    ;;
  unknown|*)
    log "host=unknown — set ADVERSARIAL_REVIEW_HOST manually; trying gemini cascade"
    ;;
esac

# 6. Gemini cascade (fallback for both directions)
if command -v gemini >/dev/null 2>&1 && [ -f "$HOME/.gemini/oauth_creds.json" ]; then
  for model in gemini-3.1-pro-preview gemini-3.1-flash-lite-preview gemini-2.5-pro gemini-2.5-flash; do
    log "trying gemini model: $model"
    out=$(printf '%s\n' "$prompt" | gemini -p "" -y -m "$model" 2>/dev/null)
    if [ -n "$out" ]; then
      log "✓ gemini ($model) returned ${#out} chars"
      printf '%s\n' "$out"
      exit 0
    fi
  done
  log "all gemini models failed or returned empty"
else
  log "gemini CLI/auth not available; skipping cascade"
fi

# 7. Degraded mode — host-self analysis with explicit banner
log "DEGRADED MODE — no external partner available; host will self-review"
printf '⚠️  DEGRADED MODE — Cross-host principle violated\n\n'
printf 'No external partner (Codex / Claude / Gemini) was reachable. '
printf 'The host is reviewing its own work, which the principle forbids — '
printf 'output below is single-perspective and may have blind spots.\n\n'
printf '── original prompt ──\n%s\n' "$prompt"
exit 2
