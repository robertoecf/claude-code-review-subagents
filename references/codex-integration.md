# Codex CLI Integration Reference

## Purpose

Optional cross-model validation using OpenAI Codex CLI. When available,
skills can invoke Codex for a second opinion on findings, improving
confidence in reviews.

## Detection

```bash
which codex && test -f ~/.codex/auth.json
```

Both conditions must pass. If either fails, skip Codex entirely.

## Invocation Pattern

```bash
codex -q "<prompt>"
```

Single-turn only. Keep prompts focused and under 500 tokens.

## When to Use

- Cross-model validation of security findings
- Codebase feasibility checks (plan-review)
- Verifying complex edge cases where a second model perspective helps

## When NOT to Use

- Simple reviews with obvious findings
- Token-constrained sessions
- No auth available (detection fails)
- Prompt analysis (Claude is the better model for meta-prompt work)

## Graceful Degradation

If Codex is unavailable, all analysis runs within Claude only. No skill
should fail or degrade quality because Codex is missing. Codex findings
are additive, never required.

## Output Noise

Codex CLI sometimes prepends output noise. If the first line starts with
"Loaded", strip it before processing the response.

## Disagreement Handling

When Claude and Codex disagree on a finding:
1. Flag the disagreement explicitly in the output
2. Present both perspectives with reasoning
3. Recommend the more conservative (higher severity) assessment
4. Tag with `[cross-model disagreement]`
