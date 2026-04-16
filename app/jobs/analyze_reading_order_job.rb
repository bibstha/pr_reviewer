class AnalyzeReadingOrderJob < ApplicationJob
  def perform(review_id)
    review = Review.find(review_id)

    # Don't re-process completed or failed reviews
    return if review.status.in?(%w[ready failed])

    review.update!(status: "analyzing")

    reading_order = ReadingOrderAnalyzer.call(
      diff_raw: review.diff_raw,
      pr_body: review.body
    )

    review.update!(
      reading_order: reading_order,
      status: "ready"
    )
  rescue => e
    Rails.logger.error("AnalyzeReadingOrderJob failed for review #{review_id}: #{e.message}")
    Review.where(id: review_id).update_all(status: "failed")
  end
end
