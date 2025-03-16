# lib/scrapers/ux_matters_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class UxMattersScraper < BaseScraper
    SOURCE_NAME = "UX Matters"
    BASE_URL = "https://www.uxmatters.com/"
    RSS_URL = "https://rss.app/feeds/HgtKv6iccCcVE38g.xml"

    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
      super(from_date, to_date)
    end

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      puts "Date range: #{from_date} to #{to_date}"
      response = HTTParty.get(RSS_URL)
      puts "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          # Parse the XML using Nokogiri
          feed_doc = Nokogiri::XML(response.body)
          items = feed_doc.css('item')
          puts "Found #{items.count} articles in feed"

          items.each do |item|
            title = item.at('title')&.text&.strip
            url = item.at('link')&.text&.strip

            # Skip if we don't have basic information
            next unless title && url && !title.empty? && !url.empty?

            # Clean up title by removing ":: UXmatters" suffix
            title = title.gsub(/\s*::\s*UXmatters$/, '') if title.include?(":: UXmatters")

            puts "Processing article: #{title}"

            # Extract date
            pub_date_str = item.at('pubDate')&.text&.strip
            if pub_date_str
              begin
                published_at = Time.parse(pub_date_str).to_date
                puts "  Date from feed: #{published_at}"
              rescue => e
                puts "  Error parsing date: #{e.message}"
                published_at = Date.today
              end
            else
              puts "  No date found, using today's date"
              published_at = Date.today
            end

            # Skip if outside date range
            next unless within_date_range?(published_at)
            puts "  Date in range: yes"

            # Extract author - look for creator tag or parse from description
            author = item.at('dc|creator')&.text&.strip
            if !author || author.empty?
              # Try to extract author from description
              description_html = item.at('description')&.text || ""
              description_doc = Nokogiri::HTML(description_html)

              # Look for common author patterns in the description
              author_match = description_doc.text.match(/by\s+([^\.]+)/i)
              author = author_match ? author_match[1].strip : "UX Matters"
            end

            # Clean up author name (remove "By" prefix if present)
            author = author.sub(/^by\s+/i, '').strip

            # Extract summary/description
            description_html = item.at('description')&.text || ""
            description_doc = Nokogiri::HTML(description_html)

            # Try to get a clean summary
            summary = description_doc.text.strip

            # Remove author information if it appears at the beginning
            summary = summary.sub(/^by\s+[^\.]+\.\s*/i, '')

            # Check for the generic UX Matters description and ignore it
            if summary == "Web magazine about user experience matters, providing insights and inspiration for the user experience community" ||
               summary.include?("Web magazine about user experience matters")
              summary = ""
            end

            # Truncate if too long
            if summary.length > 300
              summary = summary[0..297] + "..."
            end

            # Try to extract an image from the description or media content
            image_url = nil

            # First try media:content tag
            media_content = item.at('media|content')
            if media_content && media_content['url']
              image_url = media_content['url']
            end

            # If no media:content, try enclosure tag
            if !image_url
              enclosure = item.at('enclosure')
              if enclosure && enclosure['url'] && enclosure['type'] && enclosure['type'].start_with?('image/')
                image_url = enclosure['url']
              end
            end

            # If still no image, look for image in description HTML
            if !image_url
              first_img = description_doc.at('img')
              image_url = first_img['src'] if first_img && first_img['src']
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
