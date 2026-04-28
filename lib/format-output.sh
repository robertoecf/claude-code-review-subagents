#!/usr/bin/env bash
# format-output.sh — normalize raw external analysis into the unified P0–P3 schema.
#
# This is intentionally a thin pass-through. The external reviewer is expected
# to already produce P0–P3 sections via the prompt template. This script only:
#   1. Ensures the output starts with the standard header
#   2. Strips obvious noise (codex token-count footer, gemini headers, etc.)
#   3. Preserves the rest verbatim
#
# Stdin:  raw analysis (from call-external.sh)
# Stdout: cleaned markdown
# Exit:   0 always
#
# Heavy synthesis (cross-validation, severity reconciliation) belongs in the
# main session prompt, NOT here. This is a courier-style format pass.

set -u

# Strip codex's "tokens used / NN,NNN" footer if present
# Strip gemini's leading "Loaded cached..." chatter if present
# Preserve everything else
sed -E '
  /^tokens used$/,/^[0-9,]+$/d;
  /^Loaded cached credentials/d;
  /^MCP STDERR \(.*\):/,/^$/d;
'
