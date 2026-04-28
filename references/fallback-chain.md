# Fallback chain

`lib/call-external.sh` attempts to reach an external partner in a fixed order,
with explicit logging of which one succeeded. The order is **driven by the
detected host** — the partner is always the OTHER agent, never the host.

## Critical rule

Call ONLY the FIRST available partner. Stop as soon as one succeeds. Do not
re-rank or fall through after success.

## Cross-host routing

| Detected host | Primary partner            | Tertiary fallback (Gemini cascade) | Last resort                   |
|---------------|----------------------------|------------------------------------|-------------------------------|
| `claude`      | Codex (`codex exec`)       | Gemini (4-model cascade below)     | DEGRADED — host self-review   |
| `codex`       | Claude (`claude -p` Opus xhigh) | Gemini (same cascade)         | DEGRADED — host self-review   |
| `unknown`     | (skip primary)             | Gemini cascade                     | DEGRADED — host self-review   |

The official `openai/codex-plugin-cc` plugin (slash command
`/codex:adversarial-review`) is **not** required. We invoke `codex exec`
directly so the skill works regardless of whether the official plugin is
installed.

## Detection — primary partner

### Codex (when host=claude)
```bash
which codex && test -f ~/.codex/auth.json && echo "CODEX_OK"
```
Run `codex login` once on a fresh machine. For ChatGPT-account auth, ensure
`forced_login_method = "chatgpt"` is set in `~/.codex/config.toml` (see
[`codex-integration.md`](codex-integration.md)).

### Claude (when host=codex)
```bash
which claude
```
Auth is managed by the Claude desktop / `claude login` flow. `claude -p`
fails fast if not authenticated.

## Gemini cascade (used by both directions when primary fails)

### Detection
```bash
which gemini && test -f ~/.gemini/oauth_creds.json && echo "GEMINI_OK"
```

### Model order (try in this order, stop at first non-empty stdout)

| Priority | Model ID                       | Tier              |
|----------|--------------------------------|-------------------|
| 1        | `gemini-3.1-pro-preview`       | 3.1 family best   |
| 2        | `gemini-3.1-flash-lite-preview`| 3.1 family lite   |
| 3        | `gemini-2.5-pro`               | 2.5 family best   |
| 4        | `gemini-2.5-flash`             | 2.5 family lite   |

### Invocation
```bash
printf '%s\n' "$prompt" | timeout 180 gemini -p "" -y -m <model> 2>/dev/null
```

## Degraded mode

If primary AND Gemini cascade both fail or are unavailable:

- `lib/call-external.sh` exits with code `2` (not `0`, not `1`).
- Stdout begins with the literal banner:
  ```
  ⚠️  DEGRADED MODE — Cross-host principle violated
  ```
- The skill calling `call-external.sh` MUST surface this banner at the top
  of the user-facing output (see SKILL.md format examples).
- The output is single-perspective (host self-review). Treat with appropriate
  skepticism.

This is intentional — silently auto-reviewing would be the worst outcome.
The user should know the principle was bypassed.

## Forced degraded for testing

To test the degraded path **without** breaking auth:

```bash
echo "test prompt" | ADVERSARIAL_REVIEW_FORCE_DEGRADED=1 \
  bash lib/call-external.sh
```

This skips all externals and emits the banner directly.

## Anti-recursion (interaction with cascade)

`ADVERSARIAL_REVIEW_DEPTH` only guards cross-agent recursion (claude↔codex).
The Gemini cascade does NOT decrement / re-check depth — Gemini doesn't host
this skill, so there's no recursion risk.

## Cleanup

Operational logs are appended to `/tmp/call-external-codex.err` and
`/tmp/call-external-claude.err`. Delete to rotate. The script does not
auto-rotate; persistence by design.

## What this chain does NOT do

- **No Anthropic API key auth path.** Claude side uses the OAuth-managed CLI.
  If you have only an `ANTHROPIC_API_KEY`, `claude` CLI handles it
  transparently — no special handling here.
- **No OpenAI API key auth for Codex.** Codex CLI handles `OPENAI_API_KEY`
  vs ChatGPT subscription internally; we just call `codex exec`.
- **No retry on the same model.** If Codex stalls, we go to Gemini. Codex
  stalls (rare; verified) suggest backend issue, not transient — retry is
  unlikely to help in the timeout we have.
