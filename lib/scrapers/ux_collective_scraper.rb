# lib/scrapers/ux_collective_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class UxCollectiveScraper < BaseScraper
    SOURCE_NAME = "UX Collective"
    BASE_URL = "https://uxdesign.cc/"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      response = HTTParty.get(BASE_URL)
      puts "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          doc = Nokogiri::HTML(response.body)

          # UX Collective is on Medium, which typically uses article elements
          article_elements = doc.css('article, .postArticle, .js-postEntry')
          puts "Found #{article_elements.count} article elements"

          # If direct article elements aren't found, let's try an alternative approach
          if article_elements.empty?
            # Try to find the feed URL for UX Collective
            feed_url = "https://uxdesign.cc/feed"
            feed_response = HTTParty.get(feed_url)

            if feed_response.code == 200
              # Parse the feed using Nokogiri
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
                author = item.at('dc|creator')&.text || "UX Collective"

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
                title_element = article_elem.css('h2, h3, .graf--title').first
                next unless title_element
                title = title_element.text.strip

                # Extract URL
                link_element = article_elem.css('a').first
                next unless link_element
                url = link_element['href']

                # Make sure the URL is absolute
                url = "https://uxdesign.cc#{url}" unless url.start_with?('http')

                puts "Processing article: #{title}"

                # Extract date if available
                date_element = article_elem.css('time, .postMetaInline time')
                if date_element.any?
                  date_str = date_element.first.text.strip
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
                author_element = article_elem.css('.postMetaInline-authorLockup, .u-accentColor--textDarken')
                author = author_element.first&.text&.strip || "UX Collective"

                # Extract summary
                summary_element = article_elem.css('.graf--subtitle, p').first
                summary = summary_element&.text&.strip || ""

                # Extract image
                image_element = article_elem.css('img').first
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
