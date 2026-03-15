# AGENTS.md — Universal Review Agent Guidelines

## Plugin Architecture

This plugin uses a **courier pattern**: haiku subagents format templates,
call external models (Codex CLI, Gemini CLI), capture responses, and
return raw findings to the main session (opus) for synthesis.

## Agent Roles

| Role | Model | What it does |
|------|-------|-------------|
| Courier (adversarial skills) | haiku | Formats template → calls external CLI → returns raw output |
| Analyzer (prompt-optimize) | inherit | Runs analysis using main session's model |
| Router (review-all) | haiku | Classifies input → returns routing decision |
| Synthesizer (main session) | opus | Cross-validates, flags disagreements, produces unified output |

## Courier Rules

Courier agents (haiku) MUST:
1. Never analyze the input themselves
2. Never modify the external model's response
3. Always try the full fallback chain (Codex → Gemini → inform user)
4. Always clean up temp files, even on error
5. Always include which model was used in the return payload
6. Always include synthesis instructions for the main session

## Output Integrity (for synthesis by main session)

Every finding in the final synthesis MUST include:
1. **Severity**: P0 (critical) / P1 (high) / P2 (medium) / P3 (low)
2. **Evidence**: direct quote, line reference, or concrete scenario
3. **Recommendation**: specific, actionable fix

## Cross-Model Synthesis Format

When the main session synthesizes external model findings:
- `[cross-validated]` — both Claude and external model agree (high confidence)
- `[external-only]` — only external model caught this (needs review)
- `[claude-only]` — only Claude caught this (needs review)
- `[severity disagreement]` — models disagree on severity (take higher)

## Severity Scale

| Level | Meaning | Action |
|-------|---------|--------|
| P0 | Critical — exploitable, data loss, security breach | Must fix before merge/deploy |
| P1 | High — significant risk, likely failure mode | Should fix in this iteration |
| P2 | Medium — quality issue, minor risk | Fix when convenient |
| P3 | Low — style, minor optimization | Optional improvement |

## Fallback Chain

See `references/fallback-chain.md` for detection and invocation patterns.
Order: Codex CLI (GPT-5.4) → Gemini CLI (gemini-2.5-pro) → inform user.

## Honesty Rules

- When a review is clean, say so. Do not manufacture findings.
- When uncertain about severity, use confidence tags.
- When input is ambiguous, ask — don't guess.
