---
name: adversarial-code-review
description: "Cross-model adversarial review of code, configs, and diffs. Sends code to an external model (Codex CLI / Gemini) for independent red-team analysis, then returns raw findings for the main session to synthesize."
version: 0.3.0
model: inherit
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Agent"]
triggers:
  - "adversarial.?code"
  - "adversarial.?review"
  - "red.?team"
  - "security.?review"
  - "what.?could.?go.?wrong"
  - "find.?vulnerabilit"
  - "threat.?model"
  - "code.?review.?codex"
---

# Adversarial Code Review

Send the user's code to an external model for independent red-team
analysis, then synthesize the findings.

## Step 1: Resolve the Input

Determine the code to review:
- **Inline code**: use it directly
- **File path**: read the file with the Read tool
- **"review uncommitted"**: will use `codex review --uncommitted` (skip template flow)
- **"review --base main"**: will use `codex review --base main` (skip template flow)

If no input: ask "What code should I review? Paste it, point to a file, or say 'review uncommitted'."
If input is a plan: suggest `/adversarial-plan-review` instead.
If input is a prompt: suggest `/prompt-optimize` instead.

## Step 2: Spawn Haiku Courier Agent

### For inline/file code (template flow):

Use the Agent tool to spawn a **haiku** subagent with ONLY the courier
instructions and the filled template:

```
Agent(
  model=haiku,
  prompt="You are a CLI courier. Execute these steps exactly:

1. Check Codex CLI availability:
   Run: which codex && test -f ~/.codex/auth.json && echo CODEX || echo NO_CODEX

2. If CODEX available, write this template to a file and run it:
   Run: cat << 'EOF' > /tmp/cross-model-input.txt
   You are a red-team security and reliability analyst.
   Assume everything will fail. Prove it with concrete exploit scenarios.

   Review this code for:

   1. SECURITY
      - Injection: SQL, command, template, prompt injection
      - Authentication/Authorization: missing auth, IDOR, privilege escalation
      - Data exposure: PII in logs, secrets in config, error message leakage
      - Input validation: missing sanitization, type confusion, boundary violations
      - OWASP Top 10 systematic check

   2. ROBUSTNESS
      - Race conditions: TOCTOU, concurrent access, async hazards
      - Failure cascades: what breaks when dependency X is down?
      - Resource exhaustion: unbounded loops, memory leaks, connection pool drain
      - Timeout handling: missing timeouts, retry storms, no backoff

   3. COST
      - API cost scaling: per-request costs at volume
      - Token budgets: unbounded context, no max_tokens
      - Storage growth: append-only, missing cleanup/TTL
      - Compute: O(n^2) or worse on growing data

   ---
   <PASTE THE CODE HERE>
   ---

   Per finding provide:
   - Severity: P0 (critical) / P1 (high) / P2 (medium) / P3 (low)
   - Attack/failure scenario: step-by-step path to exploitation or failure
   - Likelihood: low/medium/high with evidence
   - Impact: low/medium/high/critical with what breaks
   - Exploit difficulty: trivial/moderate/hard
   - Mitigation options A/B/C with effort and effectiveness
   - Recommendation: specific choice with reasoning

   If multiple findings combine into a worse scenario, document the exploit chain.
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

**IMPORTANT**: Replace `<PASTE THE CODE HERE>` with the actual code from Step 1.

### For git reviews (codex review flow):

Spawn haiku with a simpler prompt:
```
Agent(
  model=haiku,
  prompt="You are a CLI courier. Execute:
1. Run: codex review --uncommitted 2>&1 | tee /tmp/cross-model-output.md
2. Run: cat /tmp/cross-model-output.md
3. Run: rm -f /tmp/cross-model-output.md
4. Return the full output."
)
```

### Context Limit Fallback

If the haiku Agent fails due to context limits, retry with:
1. `Agent(model=sonnet, ...)` — same prompt
2. If sonnet also fails: `Agent(model=opus, ...)` — same prompt
3. If all fail: run the Codex CLI commands directly in the main session

## Step 3: Receive and Present Results

When the agent returns, format the output as:

```markdown
## Cross-Model Code Review Results
- **External model**: [GPT-5.4 via Codex CLI | Gemini 2.5 Pro | unavailable]
- **Courier model**: [haiku | sonnet | opus | direct]
- **Review mode**: [template | codex review --uncommitted | codex review --base]

### External Model Full Response
[raw response from the agent, unmodified]
```

Then proceed to Step 4.

## Step 4: Synthesize (Main Session)

Now YOU (the main session model) review the original code against the
external model's findings:

1. Run your own security/robustness/cost analysis
2. Cross-validate:
   - `[cross-validated]` — both you and the external model agree
   - `[external-only]` — only the external model caught this
   - `[claude-only]` — only you caught this
   - `[severity disagreement]` — you disagree on severity (take the higher)
3. Look for exploit chains where findings combine
4. Produce unified output:

```markdown
## Unified Code Review
- **Findings**: [N total — X cross-validated, Y external-only, Z Claude-only]

### Cross-Validated Findings (high confidence)
[findings both models agree on]

### External-Only Findings (needs review)
[findings only the external model caught]

### Claude-Only Findings (needs review)
[findings only Claude caught]

### Exploit Chains
[combined findings that create worse scenarios]

### Recommendations (priority-ordered)
1. [most critical action]
2. [next action]
```

## Error Paths

| Condition | Response |
|-----------|----------|
| No input | Ask for code |
| Input is a plan | Suggest `/adversarial-plan-review` |
| Input is a prompt | Suggest `/prompt-optimize` |
| All courier models fail (context) | Run Codex CLI directly in main session |
| Codex + Gemini both unavailable | Inform user, offer Claude-only review |
| External model returns empty | Report error, offer Claude-only review |
| Code too large (>2000 lines) | Warn about cost, ask model to prioritize highest-risk areas |
