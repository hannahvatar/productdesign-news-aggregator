# lib/scrapers/custom_rss_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class CustomRssScraper < BaseScraper
    SOURCE_NAME = "Custom RSS Source"
    RSS_URL = "https://rss.app/feeds/hlRd5asgRbqTPwPL.xml"

    def scrape
      Rails.logger.info "Starting scrape for: #{SOURCE_NAME} using RSS feed"
      response = HTTParty.get(RSS_URL)
      Rails.logger.info "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          feed_doc = Nokogiri::XML(response.body)
          items = feed_doc.css('item')
          Rails.logger.info "Found #{items.count} articles in feed"

          items.each do |item|
            title = item.at('title')&.text&.strip
            url = item.at('link')&.text&.strip
            pub_date_text = item.at('pubDate')&.text&.strip
            author = item.at('dc|creator')&.text || "Unknown Author"
            description_html = item.at('description')&.text || ""

            # Parse and validate the publication date
            published_at = parse_date(pub_date_text)
            next unless within_date_range?(published_at)

            # Extract summary
            description_doc = Nokogiri::HTML(description_html)
            summary = description_doc.text.strip[0..200] + "..."

            # Extract first image if available
            image_url = description_doc.at('img')&.[]('src')

            article_attributes = {
              title: title,
              url: url,
              published_at: published_at,
              source: SOURCE_NAME,
              author: author,
              summary: summary,
              image_url: image_url
            }

            articles << save_article(article_attributes)
          end
        rescue => e
          Rails.logger.error "Error parsing feed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      else
        Rails.logger.error "Failed to fetch feed: #{response.code}"
      end

      Rails.logger.info "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end
  end
end
