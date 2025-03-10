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

      # Based on the debugging output, we need to look for links with '/p/' in the href
      # These are the article links in the archive
      article_links = doc.css('a').select { |link| link['href'] && link['href'].include?('/p/') }

      # Remove duplicates (some links appear multiple times)
      unique_urls = Set.new
      unique_article_links = article_links.select do |link|
        url = link['href']
        if unique_urls.include?(url)
          false
        else
          unique_urls.add(url)
          true
        end
      end

      puts "Found #{unique_article_links.size} unique article links"

      # Group links by URL to gather more information about each article
      articles_data = {}

      unique_article_links.each do |link|
        url = link['href']
        # Skip comment links
        next if url.include?("/comments")

        # Initialize article data if it doesn't exist
        articles_data[url] ||= {
          url: url,
          title: nil,
          published_at: nil,
          author: "Rich Holmes", # Default author from debugging output
          summary: "",
          image_url: nil
        }

        # Try to extract article title from link text
        link_text = link.text.strip
        if !link_text.empty? && articles_data[url][:title].nil?
          articles_data[url][:title] = link_text
        end

        # Look for date text near the link
        parent = link.parent
        3.times do # Look up to 3 levels
          date_text = parent.text.match(/(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}(?:\s+•\s+[\w\s]+)?/)
          if date_text
            articles_data[url][:date_str] = date_text[0]
            break
          end
          parent = parent.parent
          break unless parent
        end
      end

      # Process each article data
      articles_data.each do |url, data|
        article = process_article_data(data)
        articles << article if article
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end

    private

    def process_article_data(data)
      begin
        url = data[:url]
        title = data[:title]

        # Skip if we don't have enough data
        return nil if url.nil? || title.nil?

        # Make sure URL is absolute
        url = "https://departmentofproduct.substack.com#{url}" unless url.start_with?('http')

        puts "Processing article: #{title}"

        # Parse date if available
        published_at = nil
        if data[:date_str]
          date_str = data[:date_str]
          puts "  Date string: '#{date_str}'"

          # Extract just the date part (remove author)
          date_only = date_str.split('•').first.strip

          begin
            # Add current year if not present
            date_only = "#{date_only} #{Date.today.year}" unless date_only =~ /\d{4}/
            published_at = parse_date(date_only)
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

        article_attributes = {
          title: title,
          url: url,
          published_at: published_at,
          source: SOURCE_NAME,
          author: data[:author] || "Department of Product",
          summary: data[:summary] || "",
          image_url: data[:image_url]
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
