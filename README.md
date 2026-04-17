# pr-review

A coding-agent skill + shell wrapper that reviews a GitHub pull request by reading the actual codebase (not just the diff) and generating a single self-contained HTML report.

```
$ cd path/to/any/checkout/of/the/repo
$ pr-review 1920
pr-review [omp]: preparing worktree for owner/repo#1920
pr-review [omp]: worktree at /Users/.../repo-pr-1920
pr-review [omp]: running (ctrl-c to abort)…
[session] cwd=/Users/.../repo-pr-1920
→ read path=app/services/foo.rb
✓ (412c)
→ grep pattern=GetEnclaveMarketMakerCompaniesService
✓ (87c)
│ The service adds a new kwarg; presenter calls it.
  claude-sonnet-4-5  8s  in=37416 out=120 $0.12
● done
```

The script streams live progress (tool calls, thinking, per-turn cost), exits when the agent is done, and opens the generated HTML in your browser. Your current branch, index, and working tree are untouched.

## What the output looks like

Run against [`cli/cli#13210`](https://github.com/cli/cli/pull/13210) ("Record CI context in telemetry"):

![Overview: reading-order sidebar, before-state, problem, Mermaid architecture diagram](docs/screenshots/overview.png)

Each reviewed file gets a short summary, a 2–4 sentence review guide (citing actual symbols the agent read in the code), and its own diff rendered by diff2html:

![Per-file review: summary, details, and rendered diff](docs/screenshots/file-detail.png)

At the bottom, a verdict block with one of `ship-it` / `ship-with-nits` / `needs-changes` / `blocking-issues` plus the specific concerns a reviewer should raise:

![Verdict: ship-it badge with concrete concerns and skip count](docs/screenshots/verdict.png)

## What's in the box

```
skills/review-pr/       Skill definition (agent-agnostic: just a SKILL.md + template.html)
  SKILL.md              Prompt + workflow the agent follows
  template.html         Single-file HTML report scaffold (diff2html + marked + mermaid via CDN)

bin/pr-review           Shell entrypoint (on $PATH via ~/bin/pr-review symlink)
```

The skill is opinionated about **reading order**: it orders changed files by dependency and execution flow rather than alphabetically, so reviewers build understanding incrementally. Tests, docs, and lockfiles are excluded from the reading order (but counted in the verdict summary). The rules live in `skills/review-pr/SKILL.md`; edit them to taste.

## Why a single wrapper and not an N-way agent router

Rather than building adapters for claude / codex / cursor-agent / … (each with its own flags, auth, and stream schema), this wrapper drives **one** CLI: either [**Oh My Pi**](https://github.com/oh-my-pi/omp) (`omp`, the default — the harness this repo was built under) or [**pi-mono**](https://github.com/badlogic/pi-mono) (`pi`, Mario Zechner's minimalist upstream). They are separate projects, but they share a compatible non-interactive surface — same `--print --mode json --skill` flags, same JSON event schema — so the wrapper treats them as peers via `--agent omp|pi` with zero branching. Both already abstract Anthropic, OpenAI Codex, Google Gemini, GitHub Copilot, OpenRouter, z.ai, and others behind one CLI, one event schema, and one skill loader.

To switch providers: `--model opus`, `--model gpt-5.1-codex`, `--model anthropic/claude-sonnet-4-5`. No code change in this repo.

## Prerequisites

- [**omp**](https://github.com/oh-my-pi/omp) (default) or [**pi**](https://github.com/badlogic/pi-mono) (peer). Authenticate with at least one provider via `omp` / `pi` then `/login` inside the TUI, or API keys via env.
- [**wt**](https://github.com/bibstha/wt) — git worktree helper with PR shortcuts.
- [**gh**](https://cli.github.com/) — GitHub CLI, authenticated.
- `git`, `jq`, and a way to open HTML (`open` on macOS, `xdg-open` on Linux).

## Install

```bash
git clone https://github.com/bibstha/pr_reviewer.git
cd pr_reviewer

ln -s "$PWD/bin/pr-review" ~/bin/pr-review           # put on PATH

# Optional: also expose the skill to Claude Code for interactive use
ln -s "$PWD/skills/review-pr" ~/.claude/skills/review-pr
```

Both symlinks point back into the repo, so `git pull` updates everything in place.

## Usage

```bash
# from inside any checkout of the target repo, mid-feature or not
pr-review 1920                                      # bare PR number
pr-review owner/repo#1920                           # qualified
pr-review https://github.com/owner/repo/pull/1920   # full URL

# pick a specific model — short aliases or any raw pattern omp/pi accepts
pr-review --model opus 1920                         # → anthropic/claude-opus-4-7
pr-review --model codex 1920                        # → openai-codex/gpt-5.1-codex
pr-review --model glm 1920                          # → zai/glm-5.1
pr-review --model anthropic/claude-sonnet-4-5 1920  # raw pattern, passed through
pr-review --list-aliases                            # print the alias table

# swap binaries (default: omp; override once via env or per-call)
PR_REVIEW_AGENT=pi pr-review 1920
pr-review --agent pi 1920

# debugging: emit the agent's raw --mode json stream instead of pretty progress
pr-review --raw 1920
```

`wt switch pr:<N>` creates (or reuses) a worktree checked out at the PR head commit in a sibling directory. The agent runs in that worktree with the `review-pr` skill loaded via `--skill`, writes `pr-review-<owner>-<repo>-<N>.html`, and `open`s it.

Clean up worktrees when you're done:

```bash
wt list              # see what's live
wt remove pr:1920    # tear down a worktree and its branch
```

## How it works

1. **Parse** the PR reference (URL / `owner/repo#N` / bare number) and verify cwd is inside the matching repo.
2. **`wt switch pr:<N> -x pwd --`** — creates the worktree and prints its path (the `-x pwd` replaces the wt subshell, not the caller's shell).
3. **Invoke** `omp --print --mode json --no-session --skill <skill-dir> [--model <pattern>] <prompt>` inside the worktree.
4. **Skill** fetches PR metadata (`gh pr view`) and the diff (`gh pr diff`), then uses `Read`/`Grep` to explore the codebase around each reviewed file (tests/docs/lockfiles excluded). With real context in hand it produces:
   - `before_state` — relevant architecture prior to this PR
   - `problem` — what this PR solves
   - `diagram` — Mermaid diagram when 3+ files / cross-cutting
   - `reading_order` — files in dependency order, each with a summary + 2–4 sentence review guide
   - `verdict` — `ship-it` / `ship-with-nits` / `needs-changes` / `blocking-issues`, with a short justification and list of concrete concerns
5. **Template** is filled in and saved; the skill runs `open` on it.
6. **`pr-review`** formats the agent's JSON event stream into one-line progress updates per tool call / text block / thinking block / turn summary.

## Customizing the reading-order rules

Everything the agent knows about ordering, per-file analysis, and verdict rubric lives in `skills/review-pr/SKILL.md` as plain markdown. Edit and re-run — no rebuild, no code change.

## Why a skill and not a web app

An earlier iteration of this repo was a Rails app with Turbo, SolidQueue, an LLM proxy, and a persistent review model. It worked, but it was the wrong shape for a single-engineer review workflow: every session needed a running web server, a background worker, and a checkout service; the agent had no direct filesystem access and saw only the diff. The skill is strictly smaller — the agent runs where the code is, produces a portable HTML artifact, and has no infrastructure to maintain.
