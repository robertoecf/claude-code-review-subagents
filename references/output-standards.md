# Output Standards Reference

## Severity Scale

| Level | Label | Meaning |
|-------|-------|---------|
| P0 | Critical | Exploitable vulnerability, data loss, security breach |
| P1 | High | Significant risk, likely failure mode |
| P2 | Medium | Quality issue, minor risk |
| P3 | Low | Style, minor optimization |

## Per-Finding Template

```markdown
### [P0|P1|P2|P3] [category]: Title
- **Evidence**: [direct quote, line ref, or concrete scenario]
- **Problem**: [what's wrong and why it matters]
- **Options**:
  - A) [option] — effort: [low/med/high], effectiveness: [partial/full]
  - B) [option] — effort: [low/med/high], effectiveness: [partial/full]
  - C) Accept risk — [consequences]
- **Recommendation**: [specific choice with reasoning]
```

## Executive Summary

Every review output starts with an executive summary:
- Max 200 tokens
- Verdict or overall assessment first
- Count of findings by severity
- Top 1-2 actionable takeaways

## Token Budget Enforcement

1. Write output naturally
2. If exceeding budget, cut findings from bottom (lowest severity first)
3. Never cut P0 or P1 findings
4. If budget is still exceeded after cutting P3/P2, note truncation

## Confidence Tags

Use when certainty varies:
- `[high confidence]` — clear evidence, well-understood pattern
- `[medium confidence]` — reasonable inference, some ambiguity
- `[low confidence]` — speculative, needs verification
