---
name: adversarial-plan-review
description: "Cross-model adversarial review of implementation plans. Sends plans to an external model (Codex CLI / Gemini) for independent critique, then returns raw findings for the main session to synthesize."
version: 0.3.0
model: inherit
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Agent"]
triggers:
  - "adversarial.?plan"
  - "review.?plan"
  - "validate.?plan"
  - "check.?plan"
  - "plan.?review"
  - "before.?implement"
---

# Adversarial Plan Review

Send the user's plan to an external model for independent adversarial
critique, then synthesize the findings.

## Step 1: Extract the Plan

Extract the raw plan text from the user's input. This is what gets sent
to the external model. Store it mentally — you'll need it for the Agent prompt.

If no plan is provided: ask "What plan should I review? Paste it or point to a file."
If input is code: suggest `/adversarial-code-review` instead.

## Step 2: Spawn Haiku Courier Agent

Use the Agent tool to spawn a **haiku** subagent with ONLY the courier
instructions and the filled template. This gives haiku a fresh, small
context (~500 tokens) instead of inheriting the full conversation.

```
Agent(
  model=haiku,
  prompt="You are a CLI courier. Execute these steps exactly:

1. Check Codex CLI availability:
   Run: which codex && test -f ~/.codex/auth.json && echo CODEX || echo NO_CODEX

2. If CODEX available, write this template to a file and run it:
   Run: cat << 'EOF' > /tmp/cross-model-input.txt
   You are a senior engineering lead and adversarial reviewer.
   Review this implementation plan. Assume it will fail. Prove it.

   ---
   <PASTE THE FULL PLAN TEXT HERE>
   ---

   Validate for:
   1. Scope alignment — does the plan match stated objectives? Scope creep? Under-scoped?
   2. Missing steps — gaps in the implementation sequence? Testing? Migration?
   3. Dependency ordering — can steps execute in stated order? Circular deps?
   4. Rollback strategy — what happens if step N fails? Is each step reversible?
   5. Blast radius — what existing functionality is at risk?
   6. Success criteria — are there verifiable completion conditions?
   7. Cost estimate — estimated complexity, files changed, test impact

   Per finding provide:
   - Severity: P0 (critical) / P1 (high) / P2 (medium) / P3 (low)
   - Evidence: direct reference from the plan
   - Problem: what's wrong and why it matters
   - Recommendation: specific fix

   Overall verdict: PROCEED / REVIEW_NEEDED / RETHINK
   Provide an improved version of the plan incorporating all fixes.
   EOF

   Then run: timeout 120 codex exec --full-auto --ephemeral -o /tmp/cross-model-output.md \"$(cat /tmp/cross-model-input.txt)\"
   Then run: cat /tmp/cross-model-output.md

3. If CODEX unavailable, check Gemini:
   Run: which gemini && test -f ~/.gemini/oauth_creds.json && echo GEMINI || echo NO_GEMINI
   If GEMINI available, pipe the same template to:
   gemini -p '' -y -m gemini-2.5-pro
   and capture the output.

4. If BOTH unavailable, return:
   CROSS_MODEL_UNAVAILABLE: No external model CLI found.

5. Clean up: rm -f /tmp/cross-model-input.txt /tmp/cross-model-output.md

6. Return the FULL external model response unmodified, prefixed with which model was used (CODEX or GEMINI)."
)
```

**IMPORTANT**: Replace `<PASTE THE FULL PLAN TEXT HERE>` with the actual
plan text from Step 1 before spawning the agent.

### Context Limit Fallback

If the haiku Agent fails due to context limits, retry with:
1. `Agent(model=sonnet, ...)` — same prompt
2. If sonnet also fails: `Agent(model=opus, ...)` — same prompt
3. If all fail: run the Codex CLI commands directly in the main session

## Step 3: Receive and Present Results

When the haiku agent returns, format the output as:

```markdown
## Cross-Model Plan Review Results
- **External model**: [GPT-5.4 via Codex CLI | Gemini 2.5 Pro | unavailable]
- **Courier model**: [haiku | sonnet | opus | direct]
- **Fallback used**: [no | yes — reason]

### External Model Full Response
[raw response from the agent, unmodified]
```

Then proceed to Step 4.

## Step 4: Synthesize (Main Session)

Now YOU (the main session model) review the original plan against the
external model's findings:

1. Run your own plan validation (scope, deps, rollback, blast radius, success criteria)
2. Cross-validate:
   - `[cross-validated]` — both you and the external model agree
   - `[external-only]` — only the external model caught this
   - `[claude-only]` — only you caught this
   - `[severity disagreement]` — you disagree on severity (take the higher)
3. Produce unified output:

```markdown
## Unified Plan Review
- **Verdict**: PROCEED / REVIEW_NEEDED / RETHINK
- **Findings**: [N total — X cross-validated, Y external-only, Z Claude-only]

### Cross-Validated Findings (high confidence)
[findings both models agree on]

### External-Only Findings (needs review)
[findings only the external model caught]

### Claude-Only Findings (needs review)
[findings only Claude caught]

### Recommendations (priority-ordered)
1. [most critical action]
2. [next action]
```

## Error Paths

| Condition | Response |
|-----------|----------|
| No input | Ask for the plan |
| Input is code | Suggest `/adversarial-code-review` |
| All courier models fail (context) | Run Codex CLI directly in main session |
| Codex + Gemini both unavailable | Inform user, offer Claude-only review |
| External model returns empty | Report error, offer Claude-only review |
