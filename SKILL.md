---
name: opus-consult
description: Consult Claude Opus via local Claude Code CLI for explicit second opinions or reviews.
short_description: Explicit Opus 4.7 second-opinion workflow.
disable-model-invocation: true
---

# opus-consult

Consult Opus 4.7 as an external reviewer via Claude Code CLI. Treat the result as advisory evidence, not authority.

## Routing
- **Use when:** User asks to consult Opus/Claude, wants an external second opinion, or a task materially benefits from Opus 4.7 review of architecture, debugging, strategy, writing, or a high-stakes decision.
- **Use threaded mode when:** follow-up with Opus will improve the answer enough to justify local session persistence.
- **Don't use when:** the local agent can answer confidently, the task is routine, context cannot be safely shared off-machine, or curiosity is the only value.
- **Default:** one-shot consult, smallest context, agent synthesizes the result instead of delegating judgment.

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

Set reasoning effort by task:
- `medium`: default.
- `high`: architecture, debugging after failed attempts, security-sensitive reasoning, consequential strategy.
- `xhigh` or `max`: only for narrow, high-value questions.

## Read-only Tool Mode
- Default is no tools. Opus sees only the prompt content you provide.
- Use `--read-only --read-dir <dir>` to allow only Claude Code `Read`, `Glob`, `Grep`, and `LS` tools inside explicit directories.
- Prefer one narrow `--read-dir` over a broad repo root; never include secrets, credentials, private dumps, full home directories, or unrelated client data.
- Tell Opus which files to inspect in the prompt; do not rely on broad autonomous browsing.
- Report that read-only tools were enabled and list the read scope in your synthesis.

## Loop Policy
Start one-shot. Continue with `--session-file <path>` only when Opus asks a useful clarification, finds a flaw worth probing, or the first answer needs challenge/refinement. Stop after 2-3 Opus turns unless User explicitly asks to keep going. Threaded sessions may be locally resumable; avoid them for sensitive context unless that persistence is acceptable.

## Command
Run `scripts/opus_consult.sh` from this skill directory:

```bash
printf '%s\n' "Question for Opus..." | scripts/opus_consult.sh --effort medium
scripts/opus_consult.sh --dry-run --effort medium --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --effort medium --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --effort medium --read-only --read-dir /path/to/repo --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --session-file /path/to/topic.session --effort high --prompt-file /path/to/followup.txt
```

For strict API-key mode, add `--bare`. Prefer stdin for short prompts; use `--prompt-file` for existing or large prompt files. Helper-created scratch must be cleaned on exit.

## Output Shape
Report:
- `Opus answer`: concise summary or quoted short answer.
- `My synthesis`: what changes after considering Opus; agreements, disagreements, and recommendation.
- `Cost`: `total_cost_usd`, per-model `costUSD` if present, input/output/cache tokens, duration.
- `Next`: implement, investigate, or discard.
