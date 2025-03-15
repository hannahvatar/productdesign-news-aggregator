require_relative 'base_scraper'
require 'httparty'
require 'nokogiri'
require 'chronic'
require 'open-uri'  # Add this line to require open-uri

module Scrapers
  class UxMattersRssScraper < BaseScraper
    SOURCE_NAME = "UX Matters"
    RSS_URL = "https://rss.app/feeds/HgtKv6iccCcVE38g.xml"

    # Define the start date for filtering articles
    START_DATE = Date.new(2025, 1, 1)

    def scrape
      puts "Starting RSS scrape for: #{SOURCE_NAME}"

      articles = []

      begin
        # Fetch the RSS feed
        response = OpenURI.open_uri(
          RSS_URL,
          'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'
        )

        # Parse the XML with Nokogiri
        doc = Nokogiri::XML(response)

        # Find all items
        items = doc.xpath('//item')
        puts "Total items in feed: #{items.count}"

        items.each do |item|
          begin
            # Extract basic article details from RSS item
            title = item.xpath('./title').text.strip
            url = item.xpath('./link').text.strip

            # Parse publication date
            pub_date_str = item.xpath('./pubDate').text.strip
            published_at = parse_date(pub_date_str) || Date.today

            # Log the parsed date
            puts "Parsed date: #{published_at}"

            # Skip articles outside of date range
            next unless within_date_range?(published_at)

            # Extract summary (description)
            description = item.xpath('./description').text.strip
            summary = Nokogiri::HTML(description).text.strip[0..300]

            # Process the article page content if necessary
            article_content = nil
            begin
              article_response = HTTParty.get(url)
              article_doc = Nokogiri::HTML(article_response.body)

              # If needed, customize the selector based on the actual article page
              article_content = article_doc.css('div.article-content').text.strip
            rescue => e
              puts "Error processing article page: #{e.message}"
            end

            # Default author for the source
            author = "UX Matters"

            article_attributes = {
              title: title,
              url: url,
              published_at: published_at,
              source: SOURCE_NAME,
              author: author,
              summary: summary,
              content: article_content # Assuming content is optional
            }

            # Save the article using BaseScraper's save method
            article = save_article(article_attributes)
            articles << article if article
          rescue => e
            puts "Error processing RSS item: #{e.message}"
            puts e.backtrace.join("\n")
          end
        end
      rescue => e
        puts "Critical error during RSS scraping: #{e.message}"
        puts e.backtrace.join("\n")
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end

    # Check if the article's published date is within the desired date range
    def within_date_range?(published_at)
      published_at >= START_DATE && published_at <= Date.today
    end
  end
end
