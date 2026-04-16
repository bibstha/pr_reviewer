# frozen_string_literal: true

class GithubPrFetcher
  class Error < StandardError; end

  # Fetches PR metadata and diff from GitHub.
  #
  # @param github_token [String] OAuth token with repo access
  # @param repo_owner [String] e.g. "rails"
  # @param repo_name [String] e.g. "rails"
  # @param pr_number [Integer, String] PR number
  # @return [Hash] with :title, :body, :diff_raw
  def self.call(github_token:, repo_owner:, repo_name:, pr_number:)
    new(
      github_token: github_token,
      repo_owner: repo_owner,
      repo_name: repo_name,
      pr_number: pr_number
    ).fetch
  end

  def initialize(github_token:, repo_owner:, repo_name:, pr_number:)
    @github_token = github_token
    @repo_owner = repo_owner
    @repo_name = repo_name
    @pr_number = pr_number.to_i
  end

  def fetch
    client = Octokit::Client.new(access_token: @github_token)
    repo = "#{@repo_owner}/#{@repo_name}"

    pr = client.pull_request(repo, @pr_number)
    diff_raw = client.pull_request(repo, @pr_number, accept: "application/vnd.github.v3.diff")

    {
      title: pr[:title].to_s,
      body: pr[:body].to_s,
      diff_raw: diff_raw.to_s
    }
  rescue Octokit::Unauthorized
    raise Error, "GitHub token is invalid or expired"
  rescue Octokit::NotFound
    raise Error, "PR ##{@pr_number} not found in #{@repo_owner}/#{@repo_name}"
  rescue Octokit::TooManyRequests
    raise Error, "GitHub API rate limit exceeded"
  rescue Octokit::Error => e
    raise Error, "GitHub API error: #{e.message}"
  end
end
