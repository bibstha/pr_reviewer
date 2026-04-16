class Review < ApplicationRecord
  has_many :comments, dependent: :destroy

  validates :repo_owner, :repo_name, :pr_number, :github_token, presence: true
  validates :status, inclusion: { in: %w[fetching analyzing ready failed] }

  scope :recent_first, -> { order(created_at: :desc) }

  def pr_url
    "https://github.com/#{repo_owner}/#{repo_name}/pull/#{pr_number}"
  end

  def full_repo
    "#{repo_owner}/#{repo_name}"
  end

  def ready?
    status == "ready"
  end

  def reading_order_files
    return [] unless reading_order.is_a?(Hash)
    return [] unless reading_order["reading_order"].is_a?(Array)

    reading_order["reading_order"]
  end

  def analysis_before_state
    return "" unless reading_order.is_a?(Hash)
    reading_order["before_state"].to_s
  end

  def analysis_problem
    return "" unless reading_order.is_a?(Hash)
    reading_order["problem"].to_s
  end

end