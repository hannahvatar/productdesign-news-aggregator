# lib/scrapers/ux_planet_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class UxPlanetScraper < BaseScraper
    SOURCE_NAME = "UX Planet"
    BASE_URL = "https://uxplanet.org/"
    RSS_URL = "https://uxplanet.org/feed"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME} using feed with date distribution"
      response = HTTParty.get(RSS_URL)
      puts "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          # Parse the XML using Nokogiri
          feed_doc = Nokogiri::XML(response.body)
          items = feed_doc.css('item')
          puts "Found #{items.count} articles in feed"

          # Calculate date range spanning January 1 to current date
          start_date = Date.new(2025, 1, 1)
          end_date = Date.today
          days_in_range = (end_date - start_date).to_i

          # Distribute articles across date range
          items.each_with_index do |item, index|
            title = item.at('title').text.strip
            url = item.at('link').text.strip

            # Calculate a distributed date
            # This ensures articles span the entire date range
            offset_days = (index * days_in_range / [items.count, 1].max.to_f).to_i
            distributed_date = start_date + offset_days

            puts "Processing article: #{title}"
            puts "  Original date: #{item.at('pubDate').text.strip}"
            puts "  Distributed date: #{distributed_date}"

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
              published_at: distributed_date,
              source: SOURCE_NAME,
              author: author,
              summary: summary,
              image_url: image_url
            }

            articles << save_article(article_attributes)
            puts "Saved article: '#{title}' with date #{distributed_date}"
          end
        rescue => e
          puts "Error parsing feed: #{e.message}"
          puts e.backtrace.join("\n")
        end
      else
        puts "Failed to fetch feed: #{response.code}"
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end
  end
end
