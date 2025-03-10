# lib/scrapers/department_of_product_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class DepartmentOfProductScraper < BaseScraper
    SOURCE_NAME = "Department of Product"
    BASE_URL = "https://departmentofproduct.substack.com"
    ARCHIVE_URL = "#{BASE_URL}/archive"

    # Use the same date range as your other scrapers
    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
      super(from_date, to_date)
    end

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      puts "Date range: #{from_date} to #{to_date}"

      all_processed_urls = Set.new
      all_articles = []

      # First approach: Try to find archive links for each month in our date range
      puts "Looking for month-specific archives..."
      target_months = get_target_months

      target_months.each do |year_month|
        scrape_month_archive(year_month, all_processed_urls, all_articles)
      end

      # Second approach: Try the main archive with pagination as a fallback
      if all_articles.empty?
        puts "No articles found through month archives, trying main archive..."
        scrape_main_archive(all_processed_urls, all_articles)
      end

      # If we still don't have all months covered, try the sitemap
      missing_months = get_missing_months(all_articles)

      if !missing_months.empty?
        puts "Missing articles for months: #{missing_months.join(', ')}"
        puts "Trying to scrape Substack sitemap..."
        scrape_sitemap(missing_months, all_processed_urls, all_articles)
      end

      puts "Saved #{all_articles.count} articles from #{SOURCE_NAME}"
      all_articles
    end

    private

    def get_target_months
      # Generate array of YYYY-MM strings for each month in our date range
      months = []
      current_date = from_date.beginning_of_month

      while current_date <= to_date
        months << current_date.strftime("%Y-%m")
        current_date = current_date.next_month
      end

      months
    end

    def get_missing_months(articles)
      # Check which months in our date range don't have articles
      existing_months = articles.map { |a| a.published_at.strftime("%Y-%m") }.uniq
      get_target_months - existing_months
    end

    def scrape_month_archive(year_month, all_processed_urls, all_articles)
      # Try several URL patterns that Substack might use for monthly archives
      urls_to_try = [
        "#{ARCHIVE_URL}/#{year_month}?sort=new",
        "#{BASE_URL}/archive/#{year_month}",
        "#{BASE_URL}/p/archive/#{year_month}"
      ]

      urls_to_try.each do |url|
        puts "Trying month archive URL: #{url}"
        response = HTTParty.get(url)

        if response.code == 200
          puts "Found working month archive URL: #{url}"
          doc = Nokogiri::HTML(response.body)

          # Extract and process articles
          month_articles = extract_articles_from_page(doc, all_processed_urls)
          all_articles.concat(month_articles)

          puts "Found #{month_articles.count} articles for #{year_month}"
          break # Stop trying URLs for this month
        else
          puts "Month archive URL returned #{response.code}, trying next pattern"
        end
      end
    end

    def scrape_main_archive(all_processed_urls, all_articles)
      page = 1
      max_pages = 20 # Increase max pages to find more articles
      found_new_articles = true

      while page <= max_pages && found_new_articles
        url = page == 1 ? "#{ARCHIVE_URL}?sort=new" : "#{ARCHIVE_URL}?sort=new&page=#{page}"
        puts "Scraping archive page #{page}: #{url}"

        response = HTTParty.get(url)
        puts "Response status: #{response.code}"

        if response.code != 200
          puts "Page #{page} returned status #{response.code}, stopping pagination"
          break
        end

        doc = Nokogiri::HTML(response.body)
        page_articles = extract_articles_from_page(doc, all_processed_urls)

        # Add found articles to our collection
        all_articles.concat(page_articles)

        # Check if we found any new articles
        if page_articles.empty?
          puts "No new articles found on page #{page}, stopping pagination"
          found_new_articles = false
        else
          # Wait briefly between requests to avoid rate limiting
          sleep(1) if page > 1
          page += 1
        end
      end
    end

    def scrape_sitemap(missing_months, all_processed_urls, all_articles)
      # Try to find a sitemap
      sitemap_url = "#{BASE_URL}/sitemap.xml"
      puts "Checking sitemap at: #{sitemap_url}"

      response = HTTParty.get(sitemap_url)

      if response.code == 200
        puts "Found sitemap, parsing for articles..."
        doc = Nokogiri::XML(response.body)

        # Look for URLs containing /p/ which are likely article URLs
        article_urls = doc.css('url loc').map(&:text).select { |url| url.include?('/p/') }
        puts "Found #{article_urls.count} potential article URLs in sitemap"

        # Process each URL
        article_urls.each do |url|
          next if all_processed_urls.include?(url)
          all_processed_urls.add(url)

          # Attempt to fetch and process this article
          article = fetch_and_process_article(url)
          all_articles << article if article
        end
      else
        puts "Sitemap not found or not accessible (#{response.code})"
      end
    end

    def fetch_and_process_article(url)
      puts "Fetching article: #{url}"

      begin
        response = HTTParty.get(url)

        if response.code == 200
          doc = Nokogiri::HTML(response.body)

          # Extract title
          title_element = doc.css('h1').first
          return nil unless title_element
          title = title_element.text.strip

          # Extract date
          time_element = doc.css('time').first
          date_str = nil

          if time_element && time_element['datetime']
            date_str = time_element['datetime']
          else
            # Try to find date in the text
            date_pattern = doc.text.match(/(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}(?:\s+•\s+[\w\s]+)?/)
            date_str = date_pattern[0] if date_pattern
          end

          # If no date found, can't process this article
          return nil unless date_str

          # Add year if missing
          date_str = "#{date_str} 2025" unless date_str =~ /\d{4}/

          # Parse date
          begin
            published_at = parse_date(date_str)
          rescue => e
            puts "  Error parsing date: #{e.message}"
            return nil
          end

          # Check if in our date range
          if !within_date_range?(published_at)
            puts "  Article date #{published_at} not in range, skipping"
            return nil
          end

          # Extract summary if available
          summary_element = doc.css('.subtitle, .post-subtitle, .post-summary').first
          summary = summary_element ? summary_element.text.strip : ""

          # Extract author
          author_element = doc.css('.author-name').first
          author = author_element ? author_element.text.strip : "Rich Holmes"

          article_attributes = {
            title: title,
            url: url,
            published_at: published_at,
            source: SOURCE_NAME,
            author: author,
            summary: summary,
            image_url: nil
          }

          puts "  Processing article: #{title} (#{published_at})"
          save_article(article_attributes)
        else
          puts "  Failed to fetch article: #{response.code}"
          nil
        end
      rescue => e
        puts "  Error processing article: #{e.message}"
        nil
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

        # Make sure URL is absolute
        full_url = url.start_with?('http') ? url : "#{BASE_URL}#{url}"

        next if all_processed_urls.include?(full_url) # Skip already processed URLs

        all_processed_urls.add(full_url) # Mark as processed
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

      # Process all article data
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

    def process_article_data(data)
      begin
        url = data[:url]
        title = data[:title]

        # Skip if we don't have enough data
        return nil if url.nil? || title.nil?

        # Make sure URL is absolute
        url = "#{BASE_URL}#{url}" unless url.start_with?('http')

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
