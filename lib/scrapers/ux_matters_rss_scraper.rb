# lib/scrapers/ux_matters_rss_scraper.rb
require_relative 'base_scraper'
require 'nokogiri'
require 'open-uri'

module Scrapers
  class UxMattersRssScraper < BaseScraper
    SOURCE_NAME = "UX Matters"
    RSS_URL = "https://rss.app/feeds/HgtKv6iccCcVE38g.xml"

    def scrape
      puts "Starting RSS scrape for: #{SOURCE_NAME}"

      articles = []

      begin
        # Fetch the RSS feed directly
        response = URI.open(
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
            # Extract basic information
            title = item.xpath('./title').text.strip
            url = item.xpath('./link').text.strip

            # Parse publication date
            pub_date_str = item.xpath('./pubDate').text.strip
            published_at = begin
              DateTime.parse(pub_date_str).to_date
            rescue
              Date.today
            end

            # Skip if outside date range
            next unless within_date_range?(published_at)

            # Extract summary
            description = item.xpath('./description').text.strip
            summary = Nokogiri::HTML(description).text.strip[0..300]

            # Try to extract image from description
            doc = Nokogiri::HTML(description)
            image_url = doc.at('img')&.[]('src')

            # Default author
            author = "UX Matters"

            article_attributes = {
              title: title,
              url: url,
              published_at: published_at,
              source: SOURCE_NAME,
              author: author,
              summary: summary,
              image_url: image_url
            }

            # Save article
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
  end
end
