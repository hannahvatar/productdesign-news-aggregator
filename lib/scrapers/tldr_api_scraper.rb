# lib/scrapers/tldr_api_scraper.rb
require_relative 'base_scraper'
require 'date'

module Scrapers
  class TldrApiScraper < BaseScraper
    SOURCE_NAME = "TLDR Newsletter"
    BASE_URL = "https://tldr.tech/tech"

    # Categories to exclude
    EXCLUDED_CATEGORIES = [
      "Information Security",
      "DevOps",
      "Founders",
      "Design",
      "Marketing",
      "Crypto"
    ]

    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
      super(from_date, to_date)
    end

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      puts "Date range: #{from_date} to #{to_date}"
      puts "Excluding categories: #{EXCLUDED_CATEGORIES.join(', ')}"

      all_articles = []

      # Iterate through each date in the range
      current_date = from_date
      while current_date <= to_date
        date_str = current_date.strftime('%Y-%m-%d')
        url = "#{BASE_URL}/#{date_str}"

        puts "Scraping TLDR for date: #{date_str}"
        articles = scrape_single_day(url, current_date)
        all_articles.concat(articles)

        # Wait a moment to avoid overloading the server
        sleep(0.5)

        current_date = current_date.next_day
      end

      puts "Saved #{all_articles.count} articles from #{SOURCE_NAME}"
      all_articles
    end

    private

    def scrape_single_day(url, date)
      articles = []

      begin
        response = HTTParty.get(url)

        # Skip if not 200 (might be weekends or holidays with no newsletter)
        if response.code != 200
          puts "  No newsletter for #{date} (HTTP #{response.code}), skipping"
          return []
        end

        doc = Nokogiri::HTML(response.body)

        # Look for the main content div
        main_content = doc.css('.issue-container, .newsletter-content, main, .content').first
        unless main_content
          puts "  Could not find main content container, trying fallback selectors"
          # Fallback to looking for article-like structures directly
          main_content = doc
        end

        # Determine the current section for each article
        current_section = "General"

        # Look for section headers
        section_headers = main_content.css('h1, h2, h3').select do |h|
          h.text =~ /Big Tech|Science|Programming|Miscellaneous|Quick Links/i
        end

        puts "  Found #{section_headers.count} section headers"

        # Process articles in order of appearance, tracking which section they belong to
        processed_urls = Set.new
        main_content.css('*').each do |element|
          # Update current section if we hit a section header
          if element.name =~ /h[1-3]/
            new_section = element.text.strip

            # Check for excluded categories in the section header
            if EXCLUDED_CATEGORIES.any? { |category| new_section.include?(category) }
              puts "  Skipping excluded section: #{new_section}"
              current_section = "EXCLUDED"
            else
              current_section = new_section
              puts "  Switched to section: #{current_section}"
            end
            next
          end

          # Skip processing links if we're in an excluded section
          next if current_section == "EXCLUDED"

          # Process links that could be articles
          element.css('a[href^="http"]').each do |link|
            href = link['href']

            # Check URL for excluded categories
            if EXCLUDED_CATEGORIES.any? { |category| href.downcase.include?(category.downcase.gsub(' ', '')) }
              next
            end

            # Skip already processed URLs and non-article links
            next if processed_urls.include?(href) ||
                   href.include?('tldr.tech/signup') ||
                   href.include?('twitter.com') ||
                   href.include?('facebook.com') ||
                   href.include?('linkedin.com') ||
                   href.include?('instagram.com') ||
                   href.include?('unsubscribe') ||
                   href.include?('advertise') ||
                   href.include?('sponsor') ||
                   href.include?('goldcast.io')

            title = link.text.strip

            # Check title for excluded categories
            if EXCLUDED_CATEGORIES.any? { |category| title.include?(category) }
              next
            end

            # Skip short or irrelevant titles
            next if title.empty? || title.length < 5 || title =~ /sign up|subscribe|follow/i

            processed_urls.add(href)

            # Look for summary text
            summary = ""

            # Try to find parent paragraph
            parent_p = link.ancestors('p').first
            if parent_p
              # Extract text that isn't part of the link
              p_text = parent_p.text.strip
              summary = p_text.gsub(title, '').strip

              # Skip if summary mentions excluded categories
              if EXCLUDED_CATEGORIES.any? { |category| summary.include?(category) }
                next
              end
            end

            puts "    Found article: #{title} [#{current_section}]"

            article_attributes = {
              title: title,
              url: href,
              published_at: date,
              source: SOURCE_NAME,
              author: "TLDR - #{current_section}",
              summary: summary
            }

            article = save_article(article_attributes)
            articles << article if article
          end
        end

        puts "  Saved #{articles.count} filtered articles from TLDR on #{date}"
      rescue => e
        puts "  Error scraping TLDR for #{date}: #{e.message}"
      end

      articles
    end
  end
end
