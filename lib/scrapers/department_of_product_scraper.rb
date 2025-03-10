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

      all_processed_urls = Set.new
      all_articles = []

      # Try multiple approaches to find articles

      # Approach 1: Standard paginated archive
      scrape_archive_pages(all_processed_urls, all_articles)

      # Approach 2: Try navigating by month for January (if needed)
      if all_articles.empty? || !all_articles.any? { |a| a.published_at.month == 1 && a.published_at.year == 2025 }
        puts "No January articles found through standard pagination, trying month-specific URL..."
        scrape_month_archive("2025-01", all_processed_urls, all_articles)
      end

      # Approach 3: Try navigating directly to article pages from sitemap or other sources
      # This could be added later if needed

      puts "Saved #{all_articles.count} articles from #{SOURCE_NAME}"
      all_articles
    end

    private

    def scrape_archive_pages(all_processed_urls, all_articles)
      page = 1
      max_pages = 15

      while page <= max_pages
        url = page == 1 ? BASE_URL : "#{BASE_URL}&page=#{page}"
        puts "Scraping archive page #{page}: #{url}"

        response = HTTParty.get(url)
        puts "Response status: #{response.code}"

        # Stop if page doesn't exist
        if response.code != 200
          puts "Page #{page} returned status #{response.code}, stopping pagination"
          break
        end

        doc = Nokogiri::HTML(response.body)
        page_articles = extract_articles_from_page(doc, all_processed_urls)

        # Add found articles to our collection
        all_articles.concat(page_articles)

        # Break if we didn't find any new articles on this page
        if page_articles.empty?
          puts "No new articles found on page #{page}, stopping pagination"
          break
        end

        page += 1
      end
    end

    def scrape_month_archive(month_code, all_processed_urls, all_articles)
      # Try to get the monthly archive page
      url = "https://departmentofproduct.substack.com/archive/#{month_code}?sort=new"
      puts "Scraping month page: #{url}"

      response = HTTParty.get(url)
      puts "Month page response status: #{response.code}"

      if response.code == 200
        doc = Nokogiri::HTML(response.body)
        month_articles = extract_articles_from_page(doc, all_processed_urls)
        all_articles.concat(month_articles)
        puts "Found #{month_articles.count} additional articles for #{month_code}"
      else
        puts "Month page not available, skipping"
      end
    end

    def extract_articles_from_page(doc, all_processed_urls)
      # Look for links with '/p/' in the href (article links)
      article_links = doc.css('a').select { |link| link['href'] && link['href'].include?('/p/') }

      # Remove duplicates, comments, and already processed URLs
      unique_article_links = []

      article_links.each do |link|
        url = link['href']
        next if url.include?("/comments") # Skip comment links
        next if all_processed_urls.include?(url) # Skip already processed URLs

        all_processed_urls.add(url) # Mark as processed
        unique_article_links << link
      end

      puts "Found #{unique_article_links.size} new article links"

      # Process the articles
      process_article_links(unique_article_links)
    end

    def process_article_links(article_links)
      articles = []
      articles_data = {}

      # First pass: collect data from links
      article_links.each do |link|
        url = link['href']

        # Initialize article data
        articles_data[url] ||= {
          url: url,
          title: nil,
          published_at: nil,
          author: "Rich Holmes", # Default author
          summary: "",
          image_url: nil
        }

        # Extract title from link text
        link_text = link.text.strip
        if !link_text.empty? && articles_data[url][:title].nil?
          articles_data[url][:title] = link_text
        end

        # Look for date text near the link
        find_date_for_link(link, articles_data[url])
      end

      # Second pass: visit individual article pages for any with missing data
      # This is commented out but can be enabled if needed
      # articles_data.each do |url, data|
      #   if data[:published_at].nil? || data[:title].nil?
      #     fetch_article_details(url, data)
      #   end
      # end

      # Final pass: process all article data
      articles_data.each do |url, data|
        article = process_article_data(data)
        articles << article if article
      end

      articles
    end

    def find_date_for_link(link, article_data)
      # Try different approaches to find date

      # 1. Look in parent elements
      parent = link.parent
      3.times do # Look up to 3 levels
        break unless parent
        date_text = parent.text.match(/(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}(?:\s+•\s+[\w\s]+)?/)
        if date_text
          article_data[:date_str] = date_text[0]
          break
        end
        parent = parent.parent
      end

      # 2. Look for time elements near the link
      if article_data[:date_str].nil?
        link_parent = link.parent
        4.times do
          break unless link_parent
          time_element = link_parent.css('time').first
          if time_element && time_element['datetime']
            article_data[:date_str] = time_element['datetime']
            break
          end
          link_parent = link_parent.parent
        end
      end

      # 3. Look anywhere in the surrounding text
      if article_data[:date_str].nil?
        surrounding_text = link.parent.text
        date_match = surrounding_text.match(/(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}/)
        article_data[:date_str] = date_match[0] if date_match
      end
    end

    # Optional: fetch individual article pages if needed
    def fetch_article_details(url, article_data)
      begin
        puts "Fetching details for: #{url}"
        full_url = url.start_with?('http') ? url : "https://departmentofproduct.substack.com#{url}"
        response = HTTParty.get(full_url)

        if response.code == 200
          doc = Nokogiri::HTML(response.body)

          # Extract title if missing
          if article_data[:title].nil?
            title_element = doc.css('h1').first
            article_data[:title] = title_element.text.strip if title_element
          end

          # Extract date if missing
          if article_data[:date_str].nil?
            time_element = doc.css('time').first
            article_data[:date_str] = time_element['datetime'] if time_element && time_element['datetime']

            # Alternatively look for date text
            if article_data[:date_str].nil?
              date_text = doc.text.match(/(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}/)
              article_data[:date_str] = date_text[0] if date_text
            end
          end

          # Extract summary if empty
          if article_data[:summary].empty?
            summary_element = doc.css('.subtitle, .post-subtitle').first
            article_data[:summary] = summary_element.text.strip if summary_element
          end
        end
      rescue => e
        puts "Error fetching article details: #{e.message}"
      end
    end

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
            date_only = "#{date_only} 2025" unless date_only =~ /\d{4}/
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
