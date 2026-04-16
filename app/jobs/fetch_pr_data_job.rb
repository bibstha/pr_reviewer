class FetchPrDataJob < ApplicationJob
  def perform(review_id)
    review = Review.find(review_id)

    # Don't re-process completed or failed reviews
    return if review.status.in?(%w[ready failed])

    result = GithubPrFetcher.call(
      github_token: review.github_token,
      repo_owner: review.repo_owner,
      repo_name: review.repo_name,
      pr_number: review.pr_number
    )

    review.update!(
      title: result[:title],
      body: result[:body],
      diff_raw: result[:diff_raw]
    )

    AnalyzeReadingOrderJob.perform_later(review_id)
  rescue => e
    Rails.logger.error("FetchPrDataJob failed for review #{review_id}: #{e.message}")
    Review.where(id: review_id).update_all(status: "failed")
  end
end
