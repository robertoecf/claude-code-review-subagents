# claude-code-review-subagents

Cross-model adversarial review plugin for Claude Code. Spawns background subagents that call external AI models (Codex CLI, Gemini CLI), run independent analysis, cross-validate, and return only the final reviewed output.

## Architecture Diagram

[![Architecture](https://excalidraw.com/og/5S7Pzstx9npv10zCbtwkV)](https://excalidraw.com/#json=5S7Pzstx9npv10zCbtwkV,AJzXgdXVwoc3ojldcMgGZA)

> [Open full diagram in Excalidraw](https://excalidraw.com/#json=5S7Pzstx9npv10zCbtwkV,AJzXgdXVwoc3ojldcMgGZA)

### Adversarial Plan Review Flow

```
Main Session (Opus) ─── continues working, not blocked
       │
       └─► spawns Agent(run_in_background, inherit=opus)
                │
                ├─ 1. Fill template with plan
                ├─ 2. Codex CLI (GPT-5.4)  ◄── primary
                │     └─ fallback: Gemini CLI (2.5 Pro)
                │           └─ fallback: Claude-only
                ├─ 3. Get external model findings
                ├─ 4. Run own adversarial analysis
                ├─ 5. Cross-validate both
                │     ├─ [cross-validated] = high confidence
                │     ├─ [external-only]  = needs review
                │     └─ [claude-only]    = needs review
                └─ 6. Return ONLY:
                       ├─ Revised plan (incorporating all fixes)
                       ├─ Critics (P0-P3 severity-ordered)
                       └─ Recommendations (priority-ordered)
```

### Adversarial Code Review Flow

```
Main Session (Opus) ─── continues working, not blocked
       │
       └─► spawns Agent(run_in_background, inherit=opus)
                │
                ├─ 1. Resolve input (code / file / git diff)
                ├─ 2. Codex CLI or `codex review --uncommitted`
                │     └─ fallback: Gemini CLI
                ├─ 3. Get external red-team findings
                ├─ 4. Run own security/robustness/cost analysis
                ├─ 5. Cross-validate + find exploit chains
                └─ 6. Return ONLY:
                       ├─ Critics (P0-P3, attack scenarios)
                       ├─ Exploit chains
                       └─ Recommendations (priority-ordered)
```

### Prompt Optimize Flow

```
Main Session (inherit model) ─── runs inline, no subagent
       │
       ├─ 1. Analyze prompt (clarity, specificity, edge cases,
       │      token efficiency, conflicts, structure)
       ├─ 2. No external model call (Claude-native)
       └─ 3. Return:
              ├─ Issues found (P0-P3)
              ├─ Optimized version
              ├─ Diff
              └─ Change log with reasoning
```

## Skills

| Skill | Model | What it does |
|-------|-------|-------------|
| `/adversarial-plan-review` | inherit | Background agent: Codex/Gemini critique → cross-validate → revised plan |
| `/adversarial-code-review` | inherit | Background agent: Codex/Gemini red-team → cross-validate → unified critics |
| `/prompt-optimize` | inherit | Inline: analyze and optimize prompts (no external model) |
| `/review-all` | haiku | Classifies input type and routes to the correct skill |

## Install

```bash
claude plugin marketplace add robertoecf/claude-code-review-subagents
claude plugin install claude-code-review-subagents
```

## Prerequisites

At least one external model CLI must be authenticated:

```bash
# Primary: Codex CLI (GPT-5.4)
codex login

# Fallback: Gemini CLI (gemini-2.5-pro)
gemini auth login
```

## Usage

### Plan Review
```
/adversarial-plan-review
# Paste your implementation plan — runs in background
```

### Code Review
```
/adversarial-code-review
# Paste code, point to files, or say "review uncommitted"
```

### Prompt Optimization
```
/prompt-optimize
# Paste your system prompt or SKILL.md
```

### Auto-Route
```
/review-all
# Paste anything — classifies and routes to the right skill
```

## Fallback Chain

```
1. Codex CLI (GPT-5.4, reasoning: high) ◄── primary
2. Gemini CLI (gemini-2.5-pro)          ◄── fallback
3. Claude-only analysis                  ◄── last resort
```

## Output

The background subagent does ALL the work and returns only the final output:
- **Plan review**: revised plan + critics + recommendations
- **Code review**: unified critics + exploit chains + recommendations
- No raw dumps, no intermediate steps — just the reviewed result

## License

MIT
