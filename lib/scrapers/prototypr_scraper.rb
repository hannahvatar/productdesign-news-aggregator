# lib/scrapers/prototypr_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class PrototyprScraper < BaseScraper
    SOURCE_NAME = "Prototypr"
    FEED_URL = "https://rss.app/feeds/PPd56KV7LlxHucpv.xml"

    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
      super(from_date, to_date)
    end

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      puts "Date range: #{from_date} to #{to_date}"
      response = HTTParty.get(FEED_URL)
      puts "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          # Parse the RSS feed
          feed_doc = Nokogiri::XML(response.body)

          # Get all items from the feed
          items = feed_doc.css('item')
          puts "Found #{items.count} items in feed"

          items.each do |item|
            # Extract the title
            title = item.at('title')&.text&.strip
            next unless title && !title.empty?

            # Extract the URL (link)
            url = item.at('link')&.text&.strip
            next unless url && !url.empty?

            # Extract published date
            pub_date_element = item.at('pubDate')

            if pub_date_element && !pub_date_element.text.empty?
              date_str = pub_date_element.text.strip
              published_at = Time.parse(date_str).to_date rescue Date.today
            else
              published_at = Date.today
            end

            puts "Processing item: #{title}"
            puts "  Date: #{published_at}"

            # Skip if outside date range
            if !within_date_range?(published_at)
              puts "  Date not in range (#{from_date} to #{to_date}), skipping"
              next
            end
            puts "  Date in range: yes"

            # Extract author
            author_element = item.at('dc|creator') || item.at('author')
            author = author_element ? author_element.text.strip : "Prototypr Team"

            # Extract summary/description
            description_element = item.at('description')

            if description_element && !description_element.text.empty?
              # Parse the description HTML
              description_html = description_element.text
              description_doc = Nokogiri::HTML(description_html)

              # Get plain text of description and truncate for summary
              summary = description_doc.text.strip

              # Truncate summary if it's too long
              if summary.length > 300
                summary = summary[0..297] + "..."
              end

              # Try to find an image in the description
              image_url = nil
              first_img = description_doc.at('img')
              image_url = first_img['src'] if first_img
            else
              summary = ""
              image_url = nil
            end

            # Look for a media:content or enclosure tag for image
            if image_url.nil?
              media_content = item.at('media|content[medium="image"]') || item.at('media|thumbnail')
              image_url = media_content['url'] if media_content && media_content['url']
            end

            if image_url.nil?
              enclosure = item.at('enclosure[type^="image"]')
              image_url = enclosure['url'] if enclosure && enclosure['url']
            end

            article_attributes = {
              title: title,
              url: url,
              published_at: published_at,
              source: SOURCE_NAME,
              author: author,
              summary: summary,
              image_url: image_url
            }

            article = save_article(article_attributes)
            articles << article if article
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
