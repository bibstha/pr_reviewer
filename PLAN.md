# PR Reviewer — MVP Implementation Plan (Diff View Only)

## Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Framework | Rails 8.1 (`~> 8.1.3`) | Latest stable, SQLite default, SolidQueue built-in |
| Database | SQLite (Rails 8 default) | Single-user tool, no infra overhead. Migrate to Postgres if needed later. |
| LLM | RubyLLM (`ruby_llm`) | Unified API for Claude/GPT/Gemini/Ollama. `gem 'ruby_llm'` + `rails generate ruby_llm:install`. |
| Diff Rendering | diff2html via CDN | Loads as global `Diff2Html` — no bundler, no importmap headache. Includes highlight.js for syntax highlighting. |
| HTTP | `octokit` gem | Canonical Ruby GitHub API client. |
| Background Jobs | SolidQueue (built-in) | For LLM calls (reading order analysis can be slow). |

## Data Model

```
reviews
  id              (primary key)
  repo_owner      (string, e.g. "Coinwatch-Team")
  repo_name       (string, e.g. "token-monitor")
  pr_number       (integer, e.g. 1920)
  github_token    (string, stored encrypted or in-memory only — see notes)
  title           (string, from PR)
  body            (text, PR description)
  diff_raw        (text, full unified diff)
  reading_order   (json, LLM-generated: [{path, reason, order}])
  status          (string: "fetching" | "analyzing" | "ready")
  created_at, updated_at

comments (staged, not yet posted to GitHub)
  id              (primary key)
  review_id       (foreign key)
  file_path       (string)
  line_number     (integer, nullable — null = PR-level comment)
  body            (text)
  posted          (boolean, default false)
  created_at, updated_at
```

The `github_token` is session-sensitive. For MVP, store it in the `reviews` table and accept the tradeoff. Encrypt at rest with `ActiveRecord::Encryption` if this ever leaves localhost.

## Architecture

```
User enters PR URL + token
        │
        ▼
  ReviewsController#create
        │
        ├── Fetches PR metadata + diff via Octokit (sync)
        │   Saves review with status: "fetching"
        │
        ├── Enqueues AnalyzeReadingOrderJob (async)
        │   │
        │   ▼
        │   RubyLLM.chat with the diff + PR body
        │   Prompt: "Given this diff, identify the reading order..."
        │   Saves reading_order JSON to review
        │   Updates status: "ready"
        │
        └── Redirects to ReviewsController#show
            (Turbo polling on status, renders diff when ready)
```

## File Structure

```
app/
  models/
    review.rb
    comment.rb
  controllers/
    reviews_controller.rb
  views/
    reviews/
      new.html.erb          # Form: PR URL + token
      show.html.erb         # Diff view with reading order nav
      _file_diff.html.erb   # Partial: single file's diff
  jobs/
    analyze_reading_order_job.rb
  services/
    github_pr_fetcher.rb    # Wraps Octokit: fetch metadata + diff
    reading_order_analyzer.rb # Wraps RubyLLM: generate reading order from diff

config/
  initializers/
    ruby_llm.rb             # LLM provider config from ENV

db/
  migrate/
    xxx_create_reviews.rb
    xxx_create_comments.rb
```

## Key Flows

### 1. Loading a PR (`ReviewsController#create`)

```ruby
# app/controllers/reviews_controller.rb
def create
  owner, repo, number = parse_pr_url(params[:pr_url])
  @review = Review.create!(repo_owner: owner, repo_name: repo, pr_number: number)

  FetchPrDataJob.perform_later(@review.id, params[:github_token])
  redirect_to @review
end
```

`FetchPrDataJob` calls `GithubPrFetcher`, saves title/body/diff, then enqueues `AnalyzeReadingOrderJob`.

### 2. Reading Order Analysis (`AnalyzeReadingOrderJob`)

```ruby
# app/jobs/analyze_reading_order_job.rb
def perform(review_id)
  review = Review.find(review_id)
  result = ReadingOrderAnalyzer.call(review.diff_raw, review.body)
  review.update!(reading_order: result, status: :ready)
end
```

`ReadingOrderAnalyzer` sends the diff to RubyLLM with a structured prompt requesting:
1. Before state (what was the codebase like before this PR)
2. The problem this PR solves
3. Reading order: array of `{path, reason}` sorted by dependency/execution flow

### 3. Rendering the Diff View (`ReviewsController#show`)

- Left sidebar: file list ordered by `reading_order`, each with its reason
- Main area: full diff rendered by diff2html, sections in reading order
- Right area (future): staged comments panel
- Turbo stream polling while `status != "ready"` to show the analysis when it arrives

### 4. diff2html Integration

Load via CDN in the layout:
```erb
<%# app/views/layouts/application.html.erb %>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/diff2html/bundles/css/diff2html.min.css" />
<script src="https://cdn.jsdelivr.net/npm/diff2html/bundles/js/diff2html-ui.min.js"></script>
```

In the show view, a Stimulus controller initializes diff2html per-file:
```javascript
// app/javascript/controllers/diff_viewer_controller.js
// Connects to <div data-controller="diff-viewer" data-diff-viewer-diff-value="...">
// Creates new Diff2HtmlUI(targetElement, diffString, { fileListVisible: false })
```

## LLM Prompt for Reading Order

This is the core value — the prompt that generates the reading order. It needs to:

1. Accept the unified diff and PR description
2. Return structured JSON: `{ before_state, problem, reading_order: [{path, reason}] }`
3. Order files by dependency/execution flow, not alphabetically

RubyLLM supports structured output via schemas, which we should use:

```ruby
class ReadingOrderSchema < RubyLLM::Schema
  string :before_state
  string :problem
  array :reading_order do
    string :path
    string :reason
  end
end

chat.ask(prompt).with_schema(ReadingOrderSchema)
```

## Implementation Order

| # | Step | Depends on |
|---|------|-----------|
| 1 | `rails new` with SQLite, add gems (`ruby_llm`, `octokit`) | — |
| 2 | Generate `Review` and `Comment` models, run migrations | 1 |
| 3 | `GithubPrFetcher` service — fetch PR metadata + diff via Octokit | 1 |
| 4 | `FetchPrDataJob` — orchestrates fetch + saves to Review | 2, 3 |
| 5 | `ReadingOrderAnalyzer` service + `AnalyzeReadingOrderJob` | 1, 2 |
| 6 | `ReviewsController` (new, create, show) + views | 2, 4, 5 |
| 7 | diff2html integration (CDN + Stimulus controller) | 6 |
| 8 | Reading order navigation (sidebar + scroll-to) | 5, 7 |
| 9 | Turbo polling for analysis status | 6, 5 |

Steps 3 and 5 can be built in parallel. Steps 6 and 7 can be built in parallel once 2 is done.

## Configuration (ENV)

```
GITHUB_TOKEN     # optional default, user can override per-session
ANTHROPIC_API_KEY  # or whichever LLM provider
RUBY_LLM_MODEL    # e.g. "claude-sonnet-4-20250514"
```

## What This Delivers

A working app where you:
1. Enter a PR URL + GitHub token
2. See the diff loaded and parsed
3. Get an AI-generated reading order with before-state, problem statement, and file-by-file reasons
4. Navigate the diff in that order via a sidebar
5. Have a database ready for staged comments (next phase)
