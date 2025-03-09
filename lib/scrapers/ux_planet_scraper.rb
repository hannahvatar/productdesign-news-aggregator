# lib/scrapers/ux_planet_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class UxPlanetScraper < BaseScraper
    SOURCE_NAME = "UX Planet"
    BASE_URL = "https://uxplanet.org/"
    RSS_URL = "https://uxplanet.org/feed"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME} using feed"
      response = HTTParty.get(RSS_URL)
      puts "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          # Parse the XML using Nokogiri instead of RSS library
          feed_doc = Nokogiri::XML(response.body)
          items = feed_doc.css('item')
          puts "Found #{items.count} articles in feed"

          items.each do |item|
            title = item.at('title').text.strip
            url = item.at('link').text.strip

            # Extract date
            pub_date_str = item.at('pubDate').text.strip
            published_at = Time.parse(pub_date_str).to_date rescue Date.today

            puts "Processing article: #{title}"
            puts "  Date: #{published_at}"

            # Skip if outside date range
            next unless within_date_range?(published_at)
            puts "  Date in range: yes"

            # Extract author
            author = item.at('dc|creator')&.text || "UX Planet"

            # Extract summary/description
            description_html = item.at('description')&.text || ""
            description_doc = Nokogiri::HTML(description_html)
            summary = description_doc.text.strip[0..200] + "..."

            # Try to extract an image from the description
            image_url = nil
            first_img = description_doc.at('img')
            image_url = first_img['src'] if first_img

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
          puts "Error parsing feed: #{e.message}"
        end
      else
        puts "Failed to fetch feed: #{response.code}"
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end
  end
end
