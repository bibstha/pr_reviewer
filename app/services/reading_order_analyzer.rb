# frozen_string_literal: true

# Orchestrates LLM-based reading order analysis.
#
# Delegates the ordering strategy (prompt + schema) to ReadingOrderStrategy.
# This class handles LLM interaction and response parsing only.
#
# @example Using default strategy
#   ReadingOrderAnalyzer.call(diff_raw: diff, pr_body: body)
#
# @example Using a custom strategy
#   ReadingOrderAnalyzer.call(diff_raw: diff, pr_body: body, strategy: MyCustomStrategy)
#
class ReadingOrderAnalyzer
  class Error < StandardError; end

  def self.call(diff_raw:, pr_body: "", strategy: ReadingOrderStrategy)
    new(diff_raw: diff_raw, pr_body: pr_body, strategy: strategy).analyze
  end

  def initialize(diff_raw:, pr_body:, strategy:)
    @diff_raw = diff_raw
    @pr_body = pr_body
    @strategy = strategy
  end

  def analyze
    raise Error, "Cannot analyze an empty diff" if @diff_raw.strip.empty?

    # TODO: For very large diffs (>100k chars), consider truncating or summarizing
    # to stay within the model's context window. RubyLLM will raise
    # RubyLLM::ContextLengthExceededError if the prompt exceeds token limits.
    response = RubyLLM.chat
      .with_model("gpt-4.1-mini")
      .with_schema(@strategy::Schema)
      .with_instructions(@strategy.system_prompt)
      .ask(@strategy.build_user_prompt(diff_raw: @diff_raw, pr_body: @pr_body))

    parse_response(response)
  rescue RubyLLM::ContextLengthExceededError
    raise Error, "Diff is too large for the LLM context window"
  rescue RubyLLM::Error => e
    raise Error, "LLM error: #{e.message}"
  end

  private

  def parse_response(response)
    content = response.content
    parsed = parse_json(content)

    unless parsed.is_a?(Hash) && parsed.key?("reading_order") && parsed["reading_order"].is_a?(Array)
      raise Error, "LLM returned unexpected structure: expected before_state, problem, reading_order"
    end

    {
      before_state: parsed["before_state"].to_s,
      problem: parsed["problem"].to_s,
      reading_order: parsed["reading_order"].map { |item|
        { path: item["path"].to_s, reason: item["reason"].to_s }
      }
    }
  end

  def parse_json(content)
    case content
    when String
      json_str = content.gsub(/\A```(?:json)?\s*\n?/, "").gsub(/\n?```\z/, "").strip
      JSON.parse(json_str)
    when Hash
      content
    else
      raise Error, "Unexpected LLM response type: #{content.class}"
    end
  rescue JSON::ParserError => e
    raise Error, "LLM returned malformed JSON: #{e.message}"
  end
end
