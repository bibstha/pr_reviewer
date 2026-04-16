# PR Reviewer — Product Specification

## Problem

Reviewing GitHub pull requests is a multi-step manual process:

1. Pull the branch locally
2. Ask AI to summarize the diff
3. Go file-by-file to understand the changes
4. Have a conversation to solidify understanding
5. Copy-paste the review to GitHub

Existing tools (CodeRabbit, PR-Agent, Graphite) help with first-pass AI review but none address the reviewer's actual mental model:

- **Before state:** What was the codebase like before this PR? What was broken or missing?
- **The problem:** What triggered this PR (bug report, failing test, user complaint)?
- **Entry point:** Where does execution enter the fix?
- **Reading order:** Files ordered by execution flow, not alphabetically
- **Draft review:** Accumulate comments over time, refine, then post

No tool on the market provides a narrative arc or a staged comments scratchpad.

## Product

A web-based PR review workspace with three panels:

### 1. Diff View

- Fetches PR diff via GitHub API
- Groups files by the recommended reading order (not alphabetical)
  - Explains the recommended reading order so reader can follow easily
- Syntax highlighting with line numbers
- Navigation structure derived from the reading order

### 2. Chat

- Back-and-forth conversation with Claude, full diff as context
- Claude provides the opening analysis structured as:
  1. **Before state** — what was broken or missing
  2. **The problem** — what triggered this PR
  3. **Recommended reading order** — files listed in dependency/execution order, each with a one-line reason (e.g. "start here because this is where the job is enqueued, then follow to the service that processes it")
- User can ask follow-up questions pinned to specific files/lines
- Can request "Stage comment" to save a thought as a draft review comment

### 3. Staged Comments

- Scratchpad of draft review comments, each pinned to a file + line
- Editable freely before posting
- Persisted so the user can close the tab and return
- One "Post Review" button submits all staged comments to GitHub as a proper review with inline comments

## Technical Requirements

### Inputs

- PR URL or PR number + repo
- GitHub personal access token (pasted per session or remembered)

### Core Features

| Feature | Description |
|---------|-------------|
| PR Loading | Fetch diff, files, metadata via GitHub API |
| Narrative Analysis | Claude generates before-state, problem statement, and reading order |
| Guided Navigation | Diff view organized by reading order, not file name |
| Conversation | Chat with Claude about any file or line, with full diff context |
| Comment Staging | Draft inline comments pinned to file+line, editable before posting |
| Post Review | Submit all staged comments to GitHub as a single review |
| Persistence | Staged comments survive page refresh / tab close |

### Non-Goals (for MVP)

- Real-time collaboration with other reviewers
- CI/CD integration
- Auto-approval or auto-merge suggestions
- Support for GitLab / Bitbucket

## Open Questions

- **Tech stack:** Next.js? Plain React? Something else?
- **Diff rendering:** Use a library (e.g. react-diff-viewer) or build custom?
- **Persistence:** localStorage for MVP, or backend storage from day one?
- **Deployment:** Self-hosted, Vercel, or GitHub App?
- **Auth model:** Paste token each session, or OAuth via GitHub App?

## References

- [CodeRabbit](https://coderabbit.ai) — most popular AI PR review, free for open source
- [PR-Agent](https://github.com/Codium-ai/pr-agent) — open source, self-hostable, `/review` trigger
- [Graphite](https://graphite.dev) — stacked PR workflows + AI chat on PR page
- [GitHub MCP Server](https://github.com/modelcontextprotocol/servers/tree/main/src/github) — for programmatic review submission
