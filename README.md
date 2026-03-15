# claude-code-review-subagents

Cross-model adversarial review plugin for Claude Code. Uses external AI models (Codex CLI, Gemini CLI) for independent analysis, with the main Claude session performing synthesis.

## Architecture

```
Main Session (Opus) → Skill (Haiku courier) → External Model CLI → Raw findings → Opus synthesizes
```

Haiku is a dumb pipe. It formats a template, calls a CLI, returns the response. The main session (opus) does all the thinking — cross-validating external findings with its own analysis.

## Skills

| Skill | Model | What it does |
|-------|-------|-------------|
| `/adversarial-plan-review` | haiku | Sends plans to Codex/Gemini for adversarial validation |
| `/adversarial-code-review` | haiku | Sends code to Codex/Gemini for red-team security review |
| `/prompt-optimize` | inherit | Analyzes and optimizes prompts using the main session's model |
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
# Paste your implementation plan
```
Haiku sends it to Codex/Gemini → returns findings → opus synthesizes.

### Code Review
```
/adversarial-code-review
# Paste code, point to files, or say "review uncommitted"
```
Supports `codex review --uncommitted` for git diffs.

### Prompt Optimization
```
/prompt-optimize
# Paste your system prompt or SKILL.md
```
Runs on the main session model (no external call). Modes: Critique, Optimize, Compare.

### Auto-Route
```
/review-all
# Paste anything — it classifies and routes
```

## Fallback Chain

1. **Codex CLI** (GPT-5.4, reasoning: high) — primary
2. **Gemini CLI** (gemini-2.5-pro) — fallback
3. All unavailable — informs user, suggests authentication

## Output

The main session receives raw external model findings plus synthesis instructions:
- Cross-validates with its own analysis
- Flags agreements `[high confidence]` and disagreements `[needs review]`
- Produces unified recommendations with P0-P3 severity ratings

## License

MIT
