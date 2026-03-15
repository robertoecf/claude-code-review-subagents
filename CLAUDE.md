# CLAUDE.md — Claude Code Directives

## Plugin: claude-code-review-subagents v0.1.0

Review triad plugin providing prompt optimization, adversarial red-team
review, plan validation, and intelligent orchestration.

## Tool Preferences

- Use `Read` over `cat` / `head` / `tail`
- Use `Grep` over `grep` / `rg`
- Use `Glob` over `find` / `ls`
- Use `Edit` over `sed` / `awk`

## Skill Invocation

Available skills (invoke via `/command`):
- `/prompt-optimize` — analyze and optimize prompts, system instructions, skill definitions
- `/adversarial-review` — red-team review of code, configs, plans, or prompts
- `/plan-review` — validate implementation plans before execution
- `/review-all` — orchestrator that routes to the right reviewer(s)

## Agent Spawning (Orchestrator)

The `/review-all` orchestrator uses the `Agent` tool to run reviewers in
parallel when input contains multiple content types. Use `subagent_type`
for specialized routing.

## File Size Discipline

No single file in this plugin should exceed 500 lines. If a skill needs
more space, decompose into referenced files under `references/`.

## Review-Only Constraint

All skills in this plugin are strictly review-only. They read and analyze
but never modify the target codebase. Output is findings + recommendations.
