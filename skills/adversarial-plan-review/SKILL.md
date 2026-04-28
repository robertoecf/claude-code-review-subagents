---
name: adversarial-plan-review
description: "Cross-host adversarial review of an implementation plan. Routes the review to the agent that is NOT the host — Codex if you are running in Claude Code, Claude Opus if you are running in Codex. Cross-validates against your own independent analysis, returns a revised plan with critics and a verdict. Falls back to Gemini cascade, then degraded host-self with an explicit warning."
version: 0.5.0
model: inherit
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
triggers:
  - "adversarial.?plan"
  - "review.?plan"
  - "validate.?plan"
  - "check.?plan"
  - "plan.?review"
  - "before.?implement"
---

# Adversarial Plan Review

Pre-implementation review of a plan. The host (you, the agent reading this)
**must not review your own work** — route the heavy critique to the other
agent. This SKILL.md is the same in Claude Code and Codex; `lib/call-external.sh`
detects which host you are and picks the opposite partner.

## Cross-host principle

- You are running in **Claude Code** → external reviewer is **Codex**
- You are running in **Codex** → external reviewer is **Claude (Opus, xhigh)**
- All externals unavailable → **DEGRADED MODE**: host self-review with explicit
  banner. Never silently auto-review.

## How to execute

### 1. Resolve the plan

If user gave plan text inline → use it.
If user pointed to a file → use the `Read` tool on the file.
If input is **code or a diff** → suggest `/adversarial-review:coding-adversarial-review`
instead and stop here.
If no input → ask: "What plan should I review? Paste it or point to a file."

### 2. Build the external-reviewer prompt

Use this template, replacing `{PLAN_TEXT}` with the actual plan:

```
You are an adversarial plan reviewer. Assume this plan will fail. Prove it.

PLAN:
{PLAN_TEXT}

Validate for:
1. Scope alignment — does the plan match stated objectives?
2. Missing steps — gaps in sequence (testing, migration, rollback)?
3. Dependency ordering — can steps execute as ordered? Circular deps?
4. Rollback strategy — what if step N fails? Reversible?
5. Blast radius — what existing functionality is at risk?
6. Success criteria — verifiable completion conditions?
7. Cost estimate — complexity, files changed, test impact

Output language: same as the input plan.
Sections: BLOCKERS / SHOULD FIX / NICE TO HAVE / VERDICT
Per finding: P0–P3 severity, evidence (line of plan), problem, recommendation.
Verdict: PROCEED / REVIEW_NEEDED / RETHINK
Provide an improved version of the plan incorporating the recommendations.
```

Keep the prompt focused. If the plan is over ~6 kB, summarize sections instead
of pasting raw — long prompts can stall the external backend.

### 3. Call the external partner

Pipe the prompt into `lib/call-external.sh` (this script handles host detection,
routing, anti-recursion, Gemini fallback, and degraded mode):

```bash
PLUGIN_DIR="$HOME/Documents/Repos/coding-plugins/adversarial-review"  # or wherever installed
echo "$PROMPT" | bash "$PLUGIN_DIR/lib/call-external.sh"
echo "exit=$?"
```

Capture:
- **stdout** = the partner's analysis (or degraded host-self if all failed)
- **stderr** = operational logs (which partner was used, latency, fallback chain)
- **exit code** = `0` external success, `2` degraded, `1` error/recursion

Notes:
- Do **not** call `codex exec` or `claude -p` directly — always go through
  `lib/call-external.sh`. The script enforces anti-recursion via the
  `ADVERSARIAL_REVIEW_DEPTH` env counter.
- If exit is `1` (recursion), you are inside a partner-launched call; emit a
  short note ("recursion guard tripped — parent already running review") and
  stop. Do not produce a self-review.

### 4. Run your own independent analysis (host-side)

Without looking at the partner's output, walk the same checklist (scope, missing
steps, ordering, rollback, blast radius, success criteria). This is your
host-side draft.

### 5. Cross-validate

Compare host-side findings with the partner's:

| Tag                 | Meaning                                          |
|---------------------|--------------------------------------------------|
| `[cross-validated]` | both you and partner caught it (high confidence) |
| `[external-only]`   | only the partner caught it                       |
| `[host-only]`       | only you caught it                               |

On severity disagreements, take the higher of the two.

### 6. Return unified output

Format:

```markdown
## Adversarial Plan Review

- **Mode**: <external=codex | external=claude-opus | external=gemini-3.1-pro | gemini-3.1-flash-lite | gemini-2.5-pro | gemini-2.5-flash | DEGRADED>
- **Verdict**: PROCEED | REVIEW_NEEDED | RETHINK
- **Findings**: N total — X P0, Y P1, Z P2, W P3

### Critics

#### [P0]: <title>  [cross-validated | external-only | host-only]
- **Problem**: <what's wrong, why it matters>
- **Evidence**: <line of plan, quote>
- **Recommendation**: <specific fix>

[…repeat, highest severity first…]

### Revised Plan

<the complete improved plan, ready to execute — full text, not a diff>

### Key Changes from Original

1. <change> — <why>
2. <change> — <why>
```

**If `lib/call-external.sh` exited `2` (degraded mode)**, prepend this banner
verbatim to the top of the output, before the `## Adversarial Plan Review`
heading:

```
> ⚠️ **DEGRADED MODE** — no external partner reachable. Output below is
> single-perspective host self-review and violates the cross-host principle.
> Re-run after restoring access to Codex / Claude / Gemini for higher confidence.
```

## References

- `references/host-detection.md` — how `lib/detect-host.sh` decides
- `references/codex-integration.md` — Codex CLI invocation, including the
  `forced_login_method = "chatgpt"` gotcha for ChatGPT-account auth
- `references/claude-integration.md` — `claude -p --model opus --effort xhigh`
- `references/fallback-chain.md` — full external + Gemini cascade + degraded path
- `references/output-standards.md` — P0–P3 schema, evidence requirements
