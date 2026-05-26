---
name: opus-consult
description: Consult Claude Opus via local Claude Code CLI for explicit second opinions or reviews.
short_description: Explicit Opus 4.7 second-opinion workflow.
group: meta
disable-model-invocation: true
---

# opus-consult

Consult Opus 4.7 as an external reviewer via Claude Code CLI. Treat the result as advisory evidence, not authority.

## Routing
- **Use when:** User explicitly asks, or a high-stakes architecture/debugging/strategy/writing task benefits from a second model. Skip routine work, curiosity, or unsafe context.
- **Default:** one-shot, smallest context, agent synthesizes the result instead of delegating judgment. Thread only when follow-up is clearly worth local session persistence.

## Non-negotiables
- Answer model: `claude-opus-4-7`. If unavailable, stop; do not silently fall back. Claude Code may show small internal helper/router calls in `modelUsage`.
- Explicit user invocation is approval to run with the smallest safe context; do not ask for a second `Proceed?`. If the agent initiates the consult, preview scope first. Stop or redact if the needed context includes secrets, private files, full workspace dumps, or credentials.
- Auth/run mode: use the existing Claude Code login with tools disabled by default. Use `--read-only --read-dir <abs-or-relative-dir>` only when direct file inspection materially improves the consult and the read scope is safe. Use `--bare` only when User explicitly asks for the strict API-key path.
- Report `total_cost_usd`, model usage, token counts, duration, and errors from Claude Code JSON output. The helper's `$20` cap is only a runaway-spend fuse; do not ask User to choose a budget unless a lower cap matters.

## Context Policy
Choose the smallest context that lets Opus answer:
- `minimal`: question only; default for strategy, writing, and quick second opinions.
- `excerpt`: paste selected snippets with file paths/line numbers; default for code review and debugging.
- `diff`: include `git diff` only when the user asks for a change review.
- `large`: multiple files or broad architecture context; require explicit scope preview.

For code, architecture, or debugging consults, include only what Opus needs: objective, desired output shape, minimal repro/constraints, and exact snippets/files/diff/read dirs included. Exclude secrets and noise dirs (`.git`, `node_modules`, `dist`, `build`, `coverage`, `tmp`) unless explicitly required. Ask Opus to separate blockers, assumptions, and the next local check.

Set reasoning effort by task:
- `xhigh`: default for Opus consults.
- `high` or `medium`: only when the user explicitly asks for faster/cheaper output or the consult is low-stakes.

## Read-only Tool Mode
- Default is no tools. Opus sees only the prompt content you provide.
- Use `--read-only --read-dir <dir>` to allow only Claude Code `Read`, `Glob`, `Grep`, and `LS` tools inside explicit directories.
- Prefer one narrow `--read-dir` over a broad repo root; never include secrets, credentials, private dumps, full home directories, or unrelated client data.
- Read scope is directory-based; for file-specific reviews, pass the narrowest containing directory and name the relevant files in the prompt, or paste excerpts when that directory is too broad or sensitive.
- Report that read-only tools were enabled and list the read scope in your synthesis.

## Loop Policy
Start one-shot. Continue with `--session-file <path>` only when Opus asks a useful clarification, finds a flaw worth probing, or the first answer needs challenge/refinement. Stop after 2-3 Opus turns unless User explicitly asks to keep going. Threaded sessions may be locally resumable; avoid them for sensitive context unless that persistence is acceptable.

If the first answer is generic, do one follow-up only when missing context is clear and safe to share; otherwise discard it. Verify concrete findings locally before editing or claiming them.

## Command
Run `scripts/opus_consult.sh` from this skill directory:

```bash
printf '%s\n' "Question for Opus..." | scripts/opus_consult.sh
scripts/opus_consult.sh --dry-run --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --read-only --read-dir /path/to/repo --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --session-file /path/to/topic.session --prompt-file /path/to/followup.txt
```

For strict API-key mode, add `--bare`. Prefer stdin for short prompts; use `--prompt-file` for existing or large prompt files. Helper-created scratch must be cleaned on exit.

## Output Shape
Report:
- `Opus answer`: concise summary or quoted short answer.
- `My synthesis`: what changes after considering Opus; agreements, disagreements, and recommendation.
- `Cost`: `total_cost_usd`, per-model `costUSD` if present, input/output/cache tokens, duration.
- `Receipt`: context mode, read dirs if any, and session file yes/no.
- `Next`: implement, investigate, or discard.
