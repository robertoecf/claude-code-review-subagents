# CLAUDE.md — Claude Code Directives

## Plugin: claude-code-review-subagents v0.2.0

Cross-model adversarial review plugin. Uses external AI models (Codex CLI,
Gemini CLI) for independent code and plan analysis, with the main session
performing synthesis.

## Architecture

- **Courier skills** (haiku): format template → call external CLI → return raw response
- **Prompt-optimize** (inherit): runs on main session's model, no external call
- **Router** (haiku): classifies input type, returns routing decision
- **Main session** (opus): synthesizes external findings with its own analysis

## Tool Preferences

- Use `Read` over `cat` / `head` / `tail`
- Use `Grep` over `grep` / `rg`
- Use `Glob` over `find` / `ls`

## Available Skills

- `/adversarial-plan-review` — cross-model plan validation (haiku courier → Codex/Gemini)
- `/adversarial-code-review` — cross-model code red-team review (haiku courier → Codex/Gemini)
- `/prompt-optimize` — prompt analysis and optimization (runs on main session model)
- `/review-all` — router that classifies input and suggests the right skill

## File Size Discipline

No single file in this plugin should exceed 500 lines.
