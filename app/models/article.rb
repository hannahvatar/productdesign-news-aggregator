class Article < ApplicationRecord
  # Validations
  validates :title, presence: true
  validates :url, presence: true, uniqueness: true
  validates :published_at, presence: true
  validates :source, presence: true

  # Scopes
  scope :recent, -> { order(published_at: :desc) }
  scope :by_source, ->(source) { where(source: source) if source.present? }
  scope :date_range, ->(start_date, end_date) {
    where(published_at: start_date..end_date) if start_date.present? && end_date.present?
  }

  # Generate a snippet from content
  def snippet(length = 200)
    if content.present?
      ActionView::Base.full_sanitizer.sanitize(content).truncate(length)
    else
      summary
    end
  end

  # Formatted published date
  def published_date
    published_at.strftime("%B %d, %Y")
  end
end
