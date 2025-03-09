# lib/scrapers/ux_movement_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class UxMovementScraper < BaseScraper
    SOURCE_NAME = "UX Movement"
    BASE_URL = "https://uxmovement.com/"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      response = HTTParty.get(BASE_URL)
      puts "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          doc = Nokogiri::HTML(response.body)

          # UX Movement appears to use standard WordPress structure
          article_elements = doc.css('article, .post, .entry')
          puts "Found #{article_elements.count} article elements"

          # If direct article elements aren't found, try feed approach
          if article_elements.empty?
            feed_url = "https://uxmovement.com/feed/"
            feed_response = HTTParty.get(feed_url)

            if feed_response.code == 200
              feed_doc = Nokogiri::XML(feed_response.body)
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
                author = item.at('dc|creator')&.text || "UX Movement"

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
            else
              puts "Failed to fetch feed: #{feed_response.code}"
            end
          else
            # Process article elements if found
            article_elements.each do |article_elem|
              begin
                # Extract title
                title_element = article_elem.css('h2 a, h1 a, .entry-title a').first
                next unless title_element
                title = title_element.text.strip

                # Extract URL
                url = title_element['href']

                # Make sure the URL is absolute
                url = "#{BASE_URL}#{url}" unless url.start_with?('http')

                puts "Processing article: #{title}"

                # Extract date
                date_element = article_elem.css('.entry-date, .published, time')
                if date_element.any?
                  date_str = date_element.first['datetime'] || date_element.first.text.strip
                  published_at = parse_date(date_str) rescue Date.today
                else
                  # If no date found, use today's date
                  published_at = Date.today
                end

                puts "  Date: #{published_at}"

                # Skip if outside date range
                next unless within_date_range?(published_at)
                puts "  Date in range: yes"

                # Extract author
                author_element = article_elem.css('.author, .entry-author')
                author = author_element.first&.text&.strip || "UX Movement"

                # Extract summary
                summary_element = article_elem.css('.entry-summary, .excerpt, p').first
                summary = summary_element&.text&.strip || ""

                # Extract image
                image_element = article_elem.css('.post-thumbnail img, .entry-image img').first
                image_url = image_element&.[]('src')

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
              rescue => e
                puts "  Error processing article: #{e.message}"
              end
            end
          end
        rescue => e
          puts "Error parsing HTML: #{e.message}"
        end
      else
        puts "Failed to fetch page: #{response.code}"
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end
  end
end
