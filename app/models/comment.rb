class Comment < ApplicationRecord
  belongs_to :review

  validates :body, presence: true
  validates :file_path, presence: true, if: :line_number_present?

  scope :unposted, -> { where(posted: false) }
  scope :for_file, ->(path) { where(file_path: path) }

  private

  def line_number_present?
    line_number.present?
  end
end
