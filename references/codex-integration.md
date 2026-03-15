# Codex CLI Integration Reference

## Role in This Plugin

Codex CLI is the PRIMARY external model in the fallback chain.
It's used by adversarial skills as a courier target — haiku formats
a template, calls Codex, captures the response.

For the full fallback chain (Codex → Gemini → unavailable), see
`references/fallback-chain.md`.

## Environment

- **Binary**: `/opt/homebrew/bin/codex` (v0.114.0+)
- **Auth**: `~/.codex/auth.json`
- **Config**: `~/.codex/config.toml`
- **Default model**: GPT-5.4, reasoning effort: high

## Detection

```bash
which codex && test -f ~/.codex/auth.json && echo "CODEX" || echo "NO_CODEX"
```

## Template-Based Invocation

```bash
cat << 'TEMPLATE_EOF' > /tmp/cross-model-input.txt
<filled template>
TEMPLATE_EOF
timeout 120 codex exec --full-auto --ephemeral -o /tmp/cross-model-output.md "$(cat /tmp/cross-model-input.txt)"
cat /tmp/cross-model-output.md
```

## Git Review Invocation

```bash
codex review --uncommitted 2>&1 | tee /tmp/cross-model-output.md
codex review --base main 2>&1 | tee /tmp/cross-model-output.md
```

## Key Flags

| Flag | Purpose |
|------|---------|
| `--full-auto` | No approval prompts, sandboxed workspace-write |
| `--ephemeral` | Don't persist session files |
| `-o <file>` | Write final agent message to file |
| `-m <model>` | Override model |
| `-C <dir>` | Set working directory |
| `--json` | JSONL event stream |

## Cleanup

Always run after every invocation:
```bash
rm -f /tmp/cross-model-input.txt /tmp/cross-model-output.md
```
