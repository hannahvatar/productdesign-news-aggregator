# lib/scrapers/ux_planet_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class UxPlanetScraper < BaseScraper
    SOURCE_NAME = "UX Planet"
    BASE_URL = "https://uxplanet.org/"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      response = HTTParty.get(BASE_URL)
      puts "Response status: #{response.code}"
      doc = Nokogiri::HTML(response.body)

      articles = []

      # Medium publications use article tags for posts
      article_elements = doc.css('article')
      puts "Found #{article_elements.count} article elements"

      article_elements.each do |article_node|
        begin
          # Extract title - Medium typically uses h3 for article titles on the home page
          title_element = article_node.css('h3, h2, .title')
          next unless title_element.any?
          title = title_element.first.text.strip

          # Extract URL - Medium uses <a> tags around titles or entire cards
          link_element = article_node.css('a').first
          next unless link_element
          url = link_element['href']

          # Make sure the URL is absolute
          url = "https://uxplanet.org#{url}" unless url.start_with?('http')

          puts "Processing article: #{title}"

          # Extract date - Medium shows dates in various formats
          date_element = article_node.css('time, .date, .published')
          if date_element.any?
            date_str = date_element.first.text.strip
            # Medium often shows dates like "Mar 5" or "2 days ago", so we need extra parsing
            if date_str.match(/\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4}\b/i)
              # Full date like "Mar 5, 2025"
              published_at = parse_date(date_str)
            elsif date_str.match(/\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\b/i)
              # Partial date like "Mar 5", assume current year
              current_year = Date.today.year
              published_at = parse_date("#{date_str}, #{current_year}")
            elsif date_str.match(/(\d+)\s+day(?:s)?\s+ago/i)
              # Relative date like "2 days ago"
              days_ago = date_str.match(/(\d+)\s+day(?:s)?\s+ago/i)[1].to_i
              published_at = Date.today - days_ago
            else
              # If we can't parse the date, default to today
              published_at = Date.today
            end
          else
            # If no date element is found, default to today
            published_at = Date.today
          end

          puts "  Date: #{published_at}"

          # Skip if the article date is outside our target range
          next unless within_date_range?(published_at)
          puts "  Date in range: yes"

          # Extract author
          author_element = article_node.css('.author, .byline')
          author = author_element.any? ? author_element.first.text.strip : "UX Planet"

          # Extract summary
          summary_element = article_node.css('h4, .subtitle, p')
          summary = summary_element.any? ? summary_element.first.text.strip : ""

          # Extract image URL
          image_element = article_node.css('img')
          image_url = image_element.any? ? image_element.first['src'] : nil

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

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end
  end
end
