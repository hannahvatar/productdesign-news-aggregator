# lib/scrapers/smashing_magazine_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class SmashingMagazineScraper < BaseScraper
    SOURCE_NAME = "Smashing Magazine"
    BASE_URL = "https://www.smashingmagazine.com/articles/"

    # Override the initialize method to use the Jan 1, 2025 start date
    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
      super(from_date, to_date)
    end

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      puts "Date range: #{from_date} to #{to_date}"
      response = HTTParty.get(BASE_URL)
      puts "Response status: #{response.code}"
      doc = Nokogiri::HTML(response.body)

      articles = []

      # Find all article elements
      article_elements = doc.css('article.article--post')
      puts "Found #{article_elements.size} article elements"

      # Process each article
      article_elements.each do |article_node|
        article = process_article(article_node)
        articles << article if article
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end

    private

    def process_article(article_node)
      begin
        # Extract title
        title_element = article_node.css('h1, h2, h3').first
        return nil unless title_element
        title = title_element.text.strip

        # Extract URL
        link_element = title_element.css('a').first || article_node.css('a').first
        return nil unless link_element
        url = link_element['href']
        url = "https://www.smashingmagazine.com#{url}" unless url.start_with?('http')

        puts "Processing article: #{title}"

        # Extract date
        date_element = article_node.css('time').first
        if date_element && date_element['datetime']
          date_str = date_element['datetime']
        else
          # Try finding date in the text
          paragraphs = article_node.css('p')
          date_str = nil
          paragraphs.each do |p|
            text = p.text.strip
            if text =~ /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}\b/
              date_str = text.match(/\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}\b/)[0]
              break
            end
          end
        end

        puts "  Date string: '#{date_str}'"

        if !date_str || date_str.empty?
          puts "  No date found, using today's date"
          published_at = Date.today
        else
          begin
            # Parse the date
            if date_str =~ /^\d{4}-\d{2}-\d{2}$/
              # Handle YYYY-MM-DD format directly
              year, month, day = date_str.split('-').map(&:to_i)
              published_at = Date.new(year, month, day)
            else
              # Use Chronic for other formats
              published_at = parse_date(date_str)
            end
          rescue => e
            puts "  Error parsing date: #{e.message}"
            published_at = Date.today
          end
        end

        puts "  Parsed date: #{published_at}"

        # Check date range
        if !within_date_range?(published_at)
          puts "  Date not in range (#{from_date} to #{to_date}), skipping"
          return nil
        end

        puts "  Date in range: yes"

        # Extract author
        author_element = article_node.css('.author, .byline').first
        if author_element
          author = author_element.text.strip
        else
          # Look for author in text
          text = article_node.text
          author_match = text.match(/\bby\s+([A-Za-z\s]+)/i)
          author = author_match ? author_match[1].strip : "Smashing Magazine Team"
        end

        # Extract summary
        summary_element = article_node.css('p').first
        summary = ""
        if summary_element
          summary = summary_element.text.strip
                    .gsub(/\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}\s+—\s+/i, '')
                    .gsub(/Read more.*$/, '')
                    .strip
        end

        # Extract image URL
        image_element = article_node.css('img').first
        image_url = image_element ? image_element['src'] : nil

        article_attributes = {
          title: title,
          url: url,
          published_at: published_at,
          source: SOURCE_NAME,
          author: author,
          summary: summary,
          image_url: image_url
        }

        save_article(article_attributes)
      rescue => e
        puts "  Error processing article: #{e.message}"
        nil
      end
    end
  end
end
