# Cross-Model Fallback Chain

## Purpose

All adversarial review skills use external AI models for independent
analysis. This document defines the detection and invocation patterns
for each model in the fallback chain.

## Chain Order

1. **Codex CLI** (GPT-5.4) — primary
2. **Gemini CLI** (gemini-2.5-pro) — fallback 1
3. All unavailable — inform user

## Model 1: Codex CLI

### Detection
```bash
which codex && test -f ~/.codex/auth.json && echo "CODEX" || echo "NO_CODEX"
```

### Config
- Binary: `/opt/homebrew/bin/codex` (v0.114.0+)
- Auth: `~/.codex/auth.json`
- Default model: GPT-5.4, reasoning effort: high
- Sandbox: workspace-write

### Invocation (template-based)
```bash
cat << 'TEMPLATE_EOF' > /tmp/cross-model-input.txt
<filled template>
TEMPLATE_EOF
timeout 120 codex exec --full-auto --ephemeral -o /tmp/cross-model-output.md "$(cat /tmp/cross-model-input.txt)"
cat /tmp/cross-model-output.md
```

### Invocation (git review)
```bash
codex review --uncommitted 2>&1 | tee /tmp/cross-model-output.md
codex review --base main 2>&1 | tee /tmp/cross-model-output.md
codex review --commit <sha> 2>&1 | tee /tmp/cross-model-output.md
```

### Key Flags
| Flag | Purpose |
|------|---------|
| `--full-auto` | No approval prompts |
| `--ephemeral` | Don't persist session |
| `-o <file>` | Write final message to file |
| `-m <model>` | Override model |
| `-C <dir>` | Set working directory |

## Model 2: Gemini CLI

### Detection
```bash
which gemini && test -f ~/.gemini/oauth_creds.json && echo "GEMINI" || echo "NO_GEMINI"
```

### Config
- Binary: `/opt/homebrew/bin/gemini` (v0.1.11+)
- Auth: `~/.gemini/oauth_creds.json` (OAuth, robertoecf@gmail.com)
- Default model: gemini-2.5-pro

### Invocation
```bash
cat << 'TEMPLATE_EOF' | gemini -p "" -y -m gemini-2.5-pro > /tmp/cross-model-output.md 2>/dev/null
<filled template>
TEMPLATE_EOF
cat /tmp/cross-model-output.md
```

### Key Flags
| Flag | Purpose |
|------|---------|
| `-p "<prompt>"` | Non-interactive mode |
| `-y` | Auto-accept actions (YOLO mode) |
| `-m <model>` | Model selection |

## Unavailable Response

If all models in the chain are unavailable, return:
```markdown
## Cross-Model Review: UNAVAILABLE
No external model CLI available.
- Codex CLI: [not installed | no auth]
- Gemini CLI: [not installed | no auth]
Run `codex login` or `gemini auth login` to authenticate.
The main session can perform Claude-only analysis natively.
```

## Cleanup

Always run after every invocation, even on error:
```bash
rm -f /tmp/cross-model-input.txt /tmp/cross-model-output.md
```

## Future: Kimi K2.5

Not currently available on system (no CLI, no API key).
When available, add as fallback 2 between Gemini and "unavailable".
