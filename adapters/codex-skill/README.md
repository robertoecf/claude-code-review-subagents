# Codex adapter for adversarial-review

Codex discovers skills under `~/.codex/skills/<name>/SKILL.md`. This adapter
symlinks the plugin's shared `skills/` into that location so the same SKILL.md
files serve both Claude Code and Codex without duplication.

## Install

```bash
bash adapters/codex-skill/install.sh
```

Verify:

```bash
ls -la ~/.codex/skills/
```

You should see symlinks pointing back to this repo's `skills/` subdirs:

```
adversarial-plan-review -> /path/to/coding-plugins/adversarial-review/skills/adversarial-plan-review
coding-adversarial-review -> ...
prompt-optimize -> ...
review-all -> ...
```

## Use

In Codex prompts, reference a skill with the `$` prefix (Codex convention):

```
$adversarial-plan-review please review the plan I'm about to implement: ...
```

Codex will load the matching SKILL.md and follow its instructions.

## Uninstall

```bash
rm ~/.codex/skills/{adversarial-plan-review,coding-adversarial-review,prompt-optimize,review-all}
```

## Why symlinks vs copies

The plugin treats `skills/` as **single source of truth** — both the Claude
Code adapter (root `.claude-plugin/plugin.json`) and this Codex adapter point
at the same files. Edits in one place propagate to both hosts.

If the user runs the plugin under a host that doesn't follow symlinks (rare
on macOS/Linux), fall back to `cp -r` instead of `ln -s` in `install.sh`.
