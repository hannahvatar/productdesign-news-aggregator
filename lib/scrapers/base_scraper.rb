require 'httparty'
require 'nokogiri'
require 'chronic'

module Scrapers
  class BaseScraper
    attr_reader :from_date, :to_date

    def initialize(from_date = Date.new(2025, 3, 8), to_date = Date.today)
      @from_date = from_date
      @to_date = to_date
    end

    def scrape
      raise NotImplementedError, "Subclasses must implement the scrape method"
    end

    def parse_date(date_string)
      Chronic.parse(date_string)&.to_date
    end

    def within_date_range?(date)
      return false unless date
      (from_date..to_date).cover?(date)
    end

    def save_article(attributes)
      article = Article.find_or_initialize_by(url: attributes[:url])
      if article.new_record?
        article.assign_attributes(attributes)
        article.save!
        Rails.logger.info "Saved article: #{article.title} from #{article.source}"
      else
        Rails.logger.info "Article already exists: #{article.title}"
      end
      article
    end
  end
end
