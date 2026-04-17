---
name: review-pr
description: Use when the user asks to review a GitHub pull request, references a PR URL or number, or says things like "review this PR", "help me read this PR", "generate a review for PR #N". Produces a self-contained HTML review file and opens it.
---

# PR Reviewer

Generate a single-file HTML review of a GitHub pull request that orders changed files by **dependency and execution flow** instead of alphabetically, and explains what a reviewer should look at in each file — grounded in the actual codebase, not just the diff.

## Inputs

You can be invoked in a few shapes; resolve the PR before doing anything else:

- `#<N>` or bare number like `1920` — use `gh pr view <N>` in the current directory.
- `<owner>/<repo>#<N>` or full `https://github.com/.../pull/<N>` URL — use `gh pr view <url>`.
- No argument — run `gh pr status` and ask the user which one if ambiguous.

Required CLIs: `gh` (authenticated), `git`, and a way to open HTML (`open` on macOS, `xdg-open` on Linux).

## Workflow

Do these steps **in order**. Do not skip the codebase-exploration step — it's the whole reason this skill exists over a diff-only summary.

### 1. Fetch PR metadata and diff

```bash
gh pr view <pr-ref> --json number,title,body,headRefName,baseRefName,headRefOid,baseRefOid,url,author,additions,deletions
gh pr diff <pr-ref> > /tmp/pr-<N>.diff
```

Record: `title`, `body`, `number`, `url`, `headRefOid`, `baseRefOid`, and the list of changed files from the diff.

### 2. Make sure you're in the right checkout

The agent cwd **MUST** be the repo under review, checked out at (or at least containing) the PR head commit. Check:

```bash
git rev-parse HEAD
git status --porcelain
```

If HEAD doesn't match `headRefOid` and the working tree is clean, offer to check out the PR:

```bash
gh pr checkout <N>
```

If the working tree is dirty, **stop** and tell the user. Don't touch their branch.

### 3. Classify changed files

Split the list of changed files into two buckets. **Only the first bucket gets reviewed.**

**Skip these — do not appear in `reading_order`:**
- Tests: any file under `test/`, `spec/`, `tests/`, `__tests__/`, or matching `*_test.*`, `*_spec.*`, `*.test.*`, `*.spec.*`.
- Documentation: any file with extension `.md`, `.mdx`, `.rst`, `.txt`, or under a `docs/` / `doc/` directory. This includes `README.md` and `CHANGELOG.md`.
- Lockfiles: `Gemfile.lock`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `composer.lock`, `poetry.lock`, `uv.lock`, `bun.lockb`.

**Review everything else.** Record the count of skipped files by bucket — you'll list them in the verdict.

### 4. Explore the codebase

For every **reviewed** file (not the skipped bucket), before writing anything, use `Read`, `Grep`, and `Glob`:

- Read the full file (not just the diff hunks) so you understand how the changed lines fit.
- Grep for callers of any method/class added or modified.
- Read related modules: if a presenter calls a new service kwarg, read the service. If a migration adds a column, grep for the column name across the app.
- If config/schema/routes are touched, read the corresponding consumers.
- You MAY peek at a test file to confirm a behavior assertion, but do not include the test in `reading_order`.

Cite real symbols — method names, class names, column names you actually saw — in the per-file details. Don't paraphrase the diff.

### 5. Determine reading order

Order only the **reviewed** files (tests/docs/lockfiles are already excluded). Apply these rules in priority order; when rules conflict, **earlier rules win**.

1. **Dependency order dominates.** Files that define a new API, class, method, type, constant, or column must come BEFORE any file that uses them. This is the strongest rule. Example: if `service.rb` adds a `foo:` kwarg and `presenter.rb` calls `service.execute(foo: true)`, the service comes first even though the presenter is where the feature "starts".
2. Configuration, migrations, and schema changes come before the code that reads them.
3. Within peers (files with no dependency relationship), order by execution flow: the file the user/request hits first goes first.
4. NEVER order alphabetically or by directory structure. Order is semantic, not lexical.

### 6. Produce an architecture diagram (optional)

When the PR touches **3 or more reviewed files** or introduces cross-cutting changes, generate a **Mermaid** diagram illustrating the relationships between changed components.

Diagram type:
- `flowchart TD` / `flowchart LR` — execution flow, data pipelines.
- `sequenceDiagram` — request/response lifecycles.
- `classDiagram` — type hierarchies, associations.

**Mermaid syntax rules — violations cause render failures:**
- Keep labels SHORT: class/module names, no method signatures.
- NEVER put a literal `\n` inside `[...]` or `{...}` labels. Use `<br/>` for line breaks: `A["line one<br/>line two"]`.
- Wrap any label containing `#`, `:`, `()`, `,`, or other special characters in double quotes: `A["Foo#bar"]`, not `A[Foo#bar]`.
- One statement per line. No trailing newline.
- 6–10 nodes max. More is noise.

For trivial PRs (1–2 reviewed files, single change), leave the diagram field empty.

### 7. Write per-file analysis

For each file in reading order:

- **summary**: 5–10 word label for the file's role in this PR. Examples: `"New service: enclave market-maker fetch"`, `"Adds stale-row mode to enclave lookup"`.
- **details**: 2–4 sentence review guide covering:
  - What specifically changed (new class? modified method? renamed column?) with real symbol names.
  - What the reviewer should watch for (error handling, edge cases, naming).
  - Any risks, gotchas, or non-obvious decisions.

### 8. Form an overall verdict

Synthesize what you learned across all reviewed files into a single judgment. Produce two outputs:

- **`verdict_status`** — exactly one of these tokens:
  - `ship-it` — clean, focused change with no concerns. Rare.
  - `ship-with-nits` — functionally correct; minor style / naming / small polish items the author can address post-review.
  - `needs-changes` — has real issues (bugs, missing edge cases, wrong abstraction) that the author SHOULD fix before merge, but not dangerous in principle.
  - `blocking-issues` — has a correctness, security, data-loss, performance, or contract-breaking problem. Do NOT merge until resolved.
- **`verdict_summary`** — markdown text, 4–8 sentences. Cover, in this order:
  1. What this PR does well (one sentence).
  2. The single biggest risk or concern (one sentence; if none, say "no substantive concerns").
  3. Specific issues the reviewer should raise, as a short bulleted list. Cite file + line or method name. Use `- ` bullets.
  4. What was NOT reviewed: test / doc / lockfile counts from step 3, so the reviewer knows to look at them separately if they want. Example: `Skipped 4 test files and 1 doc file.`

The verdict SHOULD be calibrated honestly. Do not default to `ship-it` just because the PR is small. Do not default to `needs-changes` just to seem thorough. If you're uncertain, pick `ship-with-nits` and explain the uncertainty in the summary.

### 9. Fill in the HTML template

Read `template.html` from this skill directory, then produce the output HTML by replacing the following placeholders **verbatim** (no other edits):

| Placeholder | Replace with |
|---|---|
| `{{TITLE}}` | PR title, HTML-escaped |
| `{{REPO}}` | `<owner>/<repo>` |
| `{{PR_NUMBER}}` | PR number, e.g. `1920` |
| `{{PR_URL}}` | Full URL to the PR |
| `{{HEAD_SHA}}` | First 8 chars of `headRefOid` |
| `{{BASE_SHA}}` | First 8 chars of `baseRefOid` |
| `{{GENERATED_AT}}` | ISO-8601 timestamp, UTC |
| `{{BEFORE_STATE_MD}}` | Your `before_state` as **GitHub-flavored markdown** (raw, not HTML). Describe the codebase before this PR — architecture and conventions grounded in what you actually read. |
| `{{PROBLEM_MD}}` | Your `problem` as raw markdown. What this PR addresses. |
| `{{DIAGRAM}}` | Raw Mermaid source (no fences, no `<div>`). Empty string for trivial PRs. |
| `{{SIDEBAR_ITEMS}}` | HTML for the sidebar — see *Sidebar markup* below |
| `{{FILE_SECTIONS}}` | HTML for per-file sections — see *File section markup* below |
| `{{VERDICT_STATUS}}` | One of `ship-it`, `ship-with-nits`, `needs-changes`, `blocking-issues` (exact token, lowercase, hyphenated) |
| `{{VERDICT_LABEL}}` | Human-readable version of the status: `Ship it`, `Ship with nits`, `Needs changes`, `Blocking issues` |
| `{{VERDICT_SUMMARY_MD}}` | `verdict_summary` as raw markdown — the template JS renders it via the same `data-md` pathway |
| `{{RAW_DIFF_JSON}}` | The full unified diff as a **JSON-encoded string** (so it can be embedded in a `<script>` as `const RAW_DIFF = {{RAW_DIFF_JSON}};`). Use `JSON.stringify` mentally: escape backslashes, newlines as `\n`, quotes as `\"`. |

#### Sidebar markup

For each file, in reading order, emit one `<li>`:

```html
<li>
  <a href="#file-{{index}}" data-file="{{path}}">
    <span class="idx">{{index}}</span>
    <span class="path">{{path}}</span>
    <span class="summary">{{summary}}</span>
  </a>
</li>
```

Where `{{index}}` starts at 1 and increments. HTML-escape `{{path}}` and `{{summary}}`.

#### File section markup

For each file, in reading order:

```html
<section class="file" id="file-{{index}}">
  <header>
    <span class="idx">{{index}}</span>
    <h3>{{path}}</h3>
    <p class="summary">{{summary}}</p>
  </header>
  <div class="details markdown" data-md="{{details_md_html_attribute_escaped}}"></div>
  <div class="diff" data-file="{{path}}"></div>
</section>
```

HTML-attribute-escape the markdown (replace `&` → `&amp;`, `"` → `&quot;`, `<` → `&lt;`, `>` → `&gt;`).

### 10. Save and open

Save to `./pr-review-<owner>-<repo>-<N>.html` (kebab-case, lowercased).

Then open it:

```bash
# macOS
open ./pr-review-<owner>-<repo>-<N>.html
# Linux
xdg-open ./pr-review-<owner>-<repo>-<N>.html
```

Print the final path to the user so they can re-open it later.

## Output contract

Your final assistant message after generating the HTML **SHOULD** be brief:

```
Generated pr-review-acme-example-app-1920.html (opened in browser).

Verdict: ship-with-nits

Reading order (reviewed):
  1. app/services/.../get_enclave_market_maker_companies_service.rb
  2. app/presenters/market_maker_exchange_asset_pair_snapshot_presenter.rb

Skipped: 2 test files, 1 doc file.
```

If something went wrong (e.g., `gh` not authenticated, working tree dirty, no PR found), stop and explain. Do not emit a partial HTML.