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

      # Find the latest issue URL
      latest_issue_url = nil
      doc.css('a').each do |link|
        href = link['href']
        if href && href.include?('issue-')
          latest_issue_url = href
          break
        end
      end

      if latest_issue_url
        puts "Found latest issue URL: #{latest_issue_url}"
        issue_response = HTTParty.get(latest_issue_url)
        issue_doc = Nokogiri::HTML(issue_response.body)

        # Extract issue number and date
        issue_title = issue_doc.css('title').text.strip
        issue_match = issue_title.match(/Issue\s+#?(\d+)/i)
        issue_number = issue_match ? issue_match[1] : "Latest"

        date_text = issue_doc.text
        date_match = date_text.match(/\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}\b/i)
        if date_match
          date_str = date_match[0]
          published_at = parse_date(date_str)
        else
          published_at = Date.today
        end

        puts "Processing Issue ##{issue_number} published on #{published_at}"

        # Find articles within the issue
        article_titles = []

        # Look for article headings (usually h2 or h3 elements, or strong text)
        issue_doc.css('h2, h3, strong').each do |heading|
          title = heading.text.strip

          # Skip if title is too short or looks like a section header
          next if title.length < 10
          next if ['articles', 'sponsor', 'tools', 'resources', 'last but not least'].any? { |word| title.downcase.start_with?(word) }

          # Skip duplicate titles
          next if article_titles.include?(title)

          article_titles << title

          # Create an anchor for linking directly to this article (approximation)
          article_anchor = "#article#{article_titles.length}"

          article_attributes = {
            title: title,
            url: latest_issue_url + article_anchor,
            published_at: published_at,
            source: SOURCE_NAME,
            author: "UX Design Weekly",
            summary: "From Issue ##{issue_number}: #{title.split(":").last.to_s.strip}"
          }

          articles << save_article(article_attributes)
        end

        # If we couldn't find any articles using the above method, create one entry for the whole issue
        if articles.empty?
          puts "Couldn't find individual articles, creating entry for the whole issue"

          article_attributes = {
            title: "UX Design Weekly: Issue ##{issue_number}",
            url: latest_issue_url,
            published_at: published_at,
            source: SOURCE_NAME,
            author: "Kenny Chen",
            summary: "A curated reading list of the best user experience design links every week."
          }

          articles << save_article(article_attributes)
        end
      else
        puts "Could not find the latest issue"
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end
  end
end
