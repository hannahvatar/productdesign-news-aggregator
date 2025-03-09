# lib/scrapers/ux_design_weekly_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class UXDesignWeeklyScraper < BaseScraper
    SOURCE_NAME = "UX Design Weekly"
    BASE_URL = "https://uxdesignweekly.com/"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      response = HTTParty.get(BASE_URL)
      puts "Response status: #{response.code}"
      doc = Nokogiri::HTML(response.body)

      articles = []

      # Update selectors based on actual website structure
      issue_elements = doc.css('.issue, .newsletter, .post')
      puts "Found #{issue_elements.count} issue elements"

      issue_elements.each do |issue_node|
        begin
          # These selectors need to be updated for the actual site structure
          title_element = issue_node.css('h2, h3, .title, a')
          next if title_element.empty?

          title = title_element.text.strip
          url = title_element.css('a').attr('href')&.value || issue_node.css('a').attr('href')&.value

          puts "Processing issue: #{title}"

          # Extract date - format may vary
          date_element = issue_node.css('.date, time, .published')
          if date_element.empty?
            puts "  No date element found"
            next
          end

          date_str = date_element.text.strip
          puts "  Date string: '#{date_str}'"
          published_at = parse_date(date_str)

          if published_at.nil?
            puts "  Could not parse date from: '#{date_str}'"
            next
          end

          if within_date_range?(published_at)
            puts "  Date in range: yes"
          else
            puts "  Date in range: no (outside #{from_date} to #{to_date})"
            next
          end

          summary = issue_node.css('p, .summary, .excerpt').first&.text&.strip

          article_attributes = {
            title: title,
            url: url,
            published_at: published_at,
            source: SOURCE_NAME,
            summary: summary
          }

          articles << save_article(article_attributes)
        rescue => e
          puts "  Error processing issue: #{e.message}"
        end
      end

      puts "Saved #{articles.count} articles"
      articles
    end
  end
end
