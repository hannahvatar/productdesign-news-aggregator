# lib/scrapers/figma_release_notes_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class FigmaReleaseNotesScraper < BaseScraper
    SOURCE_NAME = "Figma Release Notes"
    FEED_URL = "https://www.figma.com/release-notes/feed/atom.xml"

    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
      super(from_date, to_date)
    end

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      puts "Date range: #{from_date} to #{to_date}"
      response = HTTParty.get(FEED_URL)
      puts "Response status: #{response.code}"

      articles = []

      if response.code == 200
        begin
          # Parse the Atom feed
          feed_doc = Nokogiri::XML(response.body)

          # Handle namespaces in the Atom feed
          feed_doc.remove_namespaces!

          # Get all entries from the feed
          entries = feed_doc.css('entry')
          puts "Found #{entries.count} entries in feed"

          entries.each do |entry|
            # Extract the title
            title = entry.at('title')&.text&.strip
            next unless title && !title.empty?

            # Extract the URL (link)
            link_element = entry.at('link[rel="alternate"]')
            url = link_element ? link_element['href'] : nil

            # If no alternate link, try the first link
            if !url || url.empty?
              url = entry.at('link')&.[]('href')
            end

            next unless url && !url.empty?

            # Extract published date
            published_element = entry.at('published') || entry.at('updated')

            if published_element && !published_element.text.empty?
              date_str = published_element.text.strip
              published_at = Time.parse(date_str).to_date rescue Date.today
            else
              published_at = Date.today
            end

            puts "Processing entry: #{title}"
            puts "  Date: #{published_at}"

            # Skip if outside date range
            if !within_date_range?(published_at)
              puts "  Date not in range (#{from_date} to #{to_date}), skipping"
              next
            end
            puts "  Date in range: yes"

            # Extract author
            author_element = entry.at('author name')
            author = author_element ? author_element.text.strip : "Figma Team"

            # Extract summary/content
            content_element = entry.at('content') || entry.at('summary')

            if content_element
              # Parse the content HTML
              content_html = content_element.text
              content_doc = Nokogiri::HTML(content_html)

              # Get plain text of content and truncate for summary
              summary = content_doc.text.strip

              # Truncate summary if it's too long
              if summary.length > 300
                summary = summary[0..297] + "..."
              end

              # Try to find an image in the content
              image_url = nil
              first_img = content_doc.at('img')
              image_url = first_img['src'] if first_img
            else
              summary = ""
              image_url = nil
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

            article = save_article(article_attributes)
            articles << article if article
          end
        rescue => e
          puts "Error parsing feed: #{e.message}"
          puts e.backtrace.join("\n")
        end
      else
        puts "Failed to fetch feed: #{response.code}"
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end
  end
end
