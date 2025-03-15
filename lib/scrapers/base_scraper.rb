# lib/scrapers/base_scraper.rb
require 'httparty'
require 'nokogiri'
require 'chronic'

module Scrapers
  class BaseScraper
    EXCLUDED_SOURCES = ['UX Movement', 'UX Design Weekly']

    attr_reader :from_date, :to_date

    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
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
      # Check if the source is in the excluded sources list
      if EXCLUDED_SOURCES.include?(attributes[:source])
        Rails.logger.info "Skipping article from excluded source: #{attributes[:source]} - #{attributes[:title]}"
        return nil
      end

      article = Article.find_or_initialize_by(url: attributes[:url])

      # Additional check to prevent saving if source is excluded
      if EXCLUDED_SOURCES.include?(article.source)
        Rails.logger.info "Preventing save of existing article from excluded source: #{article.source} - #{article.title}"
        return nil
      end

      if article.new_record?
        article.assign_attributes(attributes)
        article.save!
        Rails.logger.info "Saved article: #{article.title} from #{article.source}"
      else
        Rails.logger.info "Article already exists: #{article.title}"
      end
      article
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save article: #{e.message}"
      nil
    end
  end
end
