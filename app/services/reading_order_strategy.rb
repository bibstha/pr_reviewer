# frozen_string_literal: true

require "ruby_llm/schema"

# Defines HOW files should be ordered in a PR review.
#
# A strategy owns two things:
#   1. The system prompt that instructs the LLM on ordering rules
#   2. The output schema that structures the LLM's response
#
# To customize file ordering, either modify the prompt below or create a new
# strategy class with the same interface (.system_prompt, .schema, .build_user_prompt).
#
# Future strategies could:
#   - Use heuristics instead of LLM (parse imports, build dependency graph)
#   - Domain-specific ordering (Rails: routes → controllers → models → specs)
#   - Multi-pass: first pass groups by theme, second pass orders within groups
#
class ReadingOrderStrategy
  # Output schema — what the LLM returns.
  class Schema < RubyLLM::Schema
    description "Structured analysis of a PR diff with a recommended reading order"

    string :before_state,
           description: "What the codebase was like before this PR — architecture, existing patterns, relevant context"

    string :problem,
           description: "What problem this PR solves or what capability it adds"

    array :reading_order do
      object :item do
        string :path, description: "File path as it appears in the diff"
        string :reason, description: "One-line reason why this file should be read at this position in the order"
      end
    end
  end

  # The system prompt that guides the LLM's ordering decisions.
  # Edit this to change how files are organized.
  def self.system_prompt
    <<~PROMPT
      You are a senior engineer reviewing a pull request. Your job is to analyze the diff
      and produce an optimal reading order so a reviewer can understand the PR quickly.

      ## Rules for reading order

      1. Order files by **execution flow and dependency**, NOT alphabetically.
      2. The entry point of the change (the file where the feature/fix is triggered)
         should come first, or early in the order.
      3. Files that define new types, interfaces, or constants that other files depend on
         should come before the files that use them.
      4. Tests should come after the implementation they test — they confirm the behavior.
      5. Configuration or setup files come before the code they configure.
      6. For each file, provide a one-line reason explaining why it belongs at that position.

      ## What to include

      - `before_state`: Describe the codebase architecture and patterns relevant to this PR.
        What existed before these changes? What constraints or conventions were in place?
      - `problem`: What is broken, missing, or needed that this PR addresses?
      - `reading_order`: Ordered array of {path, reason}. Every changed file must appear
        exactly once. The order should let a reader build understanding incrementally.
    PROMPT
  end

  # Builds the user prompt from the diff and optional PR description.
  def self.build_user_prompt(diff_raw:, pr_body: "")
    parts = ["Here is a PR diff to analyze:\n\n```\n#{diff_raw}\n```"]
    parts << "\n\nPR description:\n\n#{pr_body}" unless pr_body.to_s.strip.empty?
    parts.join
  end
end
