# lib/scrapers/department_of_product_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class DepartmentOfProductScraper < BaseScraper
    SOURCE_NAME = "Department of Product"
    BASE_URL = "https://departmentofproduct.substack.com/archive?sort=new"

    # Use the same date range as your other scrapers
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

      # Find all article elements - Substack has a consistent structure
      # Posts are typically in divs with class "post-preview"
      article_elements = doc.css('.post-preview')
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
        # Extract title - it's usually in an h3 with class "post-preview-title"
        title_element = article_node.css('.post-preview-title').first
        return nil unless title_element
        title = title_element.text.strip

        # Extract URL - it's the href attribute of the title's link
        link_element = title_element.css('a').first || article_node.css('a').first
        return nil unless link_element
        url = link_element['href']
        # Make sure URL is absolute
        url = "https://departmentofproduct.substack.com#{url}" unless url.start_with?('http')

        puts "Processing article: #{title}"

        # Extract date - Substack has dates in elements with class "post-preview-date"
        date_element = article_node.css('.post-preview-date').first
        if date_element
          date_str = date_element.text.strip
          puts "  Date string: '#{date_str}'"

          # Try to parse the date
          begin
            published_at = parse_date(date_str)
            puts "  Parsed date: #{published_at}"
          rescue => e
            puts "  Error parsing date: #{e.message}"
            published_at = Date.today
          end
        else
          puts "  No date found, using today's date"
          published_at = Date.today
        end

        # Check date range
        if !within_date_range?(published_at)
          puts "  Date not in range (#{from_date} to #{to_date}), skipping"
          return nil
        end

        puts "  Date in range: yes"

        # Extract author - Substack typically has authors in elements with class "post-preview-byline"
        # If not found, use default author
        author_element = article_node.css('.post-preview-byline').first
        author = author_element ? author_element.text.strip.gsub(/^By\s+/i, '') : "Department of Product"

        # Extract summary - usually in a div with class "post-preview-description"
        summary_element = article_node.css('.post-preview-description').first
        summary = summary_element ? summary_element.text.strip : ""

        # Extract image URL - Substack often has images with class "post-preview-image"
        image_element = article_node.css('.post-preview-image img').first
        image_url = nil
        if image_element
          image_url = image_element['src']
        else
          # Try to find other image in the article
          image_element = article_node.css('img').first
          image_url = image_element ? image_element['src'] : nil
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

        save_article(article_attributes)
      rescue => e
        puts "  Error processing article: #{e.message}"
        puts "  Backtrace: #{e.backtrace.join("\n    ")}"
        nil
      end
    end
  end
end
