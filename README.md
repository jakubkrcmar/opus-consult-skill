# opus-consult

A Codex/Cursor skill for getting an explicit second opinion from Claude Opus through the local Claude Code CLI.

The skill keeps Opus consults deliberate: smallest safe context by default, tools disabled unless read-only scope is explicitly useful, no silent fallback from the requested model, and cost/usage surfaced from Claude Code JSON output.

## What It Does

- Routes explicit "consult Opus/Claude" requests to Claude Code.
- Defaults to one-shot prompts with no tools and no session persistence.
- Supports bounded threaded follow-ups through a local session file.
- Supports optional read-only file inspection with explicit `--read-dir` scope.
- Reports cost, model usage, token counts, duration, and errors.

## Requirements

- Codex or Cursor skills support.
- Claude Code CLI available as `claude` on `PATH`.
- Existing Claude Code login, or `ANTHROPIC_API_KEY` when using `--bare`.

## Install

Clone the repo into your skills directory:

```bash
git clone <repo-url> ~/.codex/skills/opus-consult
```

Or copy the folder manually so the layout is:

```text
~/.codex/skills/opus-consult/
  SKILL.md
  scripts/opus_consult.sh
```

Make sure the helper is executable:

```bash
chmod +x ~/.codex/skills/opus-consult/scripts/opus_consult.sh
```

## Usage

Ask your agent to consult Opus explicitly, for example:

```text
Use opus-consult to get a second opinion on this architecture decision.
```

You can also run the helper directly from the skill directory:

```bash
printf '%s\n' "Question for Opus..." | scripts/opus_consult.sh --effort medium
scripts/opus_consult.sh --dry-run --effort medium --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --effort high --prompt-file /path/to/prompt.txt
scripts/opus_consult.sh --effort medium --read-only --read-dir /path/to/repo --prompt-file /path/to/prompt.txt
```

## Safety Model

- Default is no tools: Opus only sees the prompt content you provide.
- Use `--read-only --read-dir <path>` only when file inspection is materially useful.
- Never include secrets, credentials, private dumps, full home directories, or unrelated client data.
- Treat Opus output as advisory evidence, not authority.

## License

MIT
