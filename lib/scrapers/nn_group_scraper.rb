# lib/scrapers/nn_group_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class NnGroupScraper < BaseScraper  # Changed from NNGroupScraper to NnGroupScraper
    SOURCE_NAME = "NN/g UX Research"
    BASE_URL = "https://www.nngroup.com/articles/"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      response = HTTParty.get(BASE_URL)
      puts "Response status: #{response.code}"
      doc = Nokogiri::HTML(response.body)

      articles = []

      # Updated selector for article teasers
      doc.css('.article.teaser').each do |article_node|
        begin
          # Extract title
          title_element = article_node.css('h2, h3, a.title').first
          next unless title_element
          title = title_element.text.strip

          # Extract URL
          link_element = article_node.css('a').first
          next unless link_element
          url = link_element['href']
          url = "https://www.nngroup.com#{url}" unless url.start_with?('http')

          puts "Processing article: #{title}"

          # Extract date
          date_element = article_node.css('.date, .pubdate, time')
          if date_element.any?
            date_str = date_element.text.strip
            # The date format looks like: "March 7, 2025Mar 7, 2025 | Article: 6 minutemins to read"
            # Extract just the date part
            date_match = date_str.match(/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}/)
            date_str = date_match[0] if date_match
          else
            date_str = nil
          end

          puts "  Date string: '#{date_str}'"
          published_at = date_str ? parse_date(date_str) : nil
          puts "  Parsed date: #{published_at || 'nil'}"

          if published_at.nil?
            puts "  Could not parse date, using today's date"
            published_at = Date.today
          end

          next unless within_date_range?(published_at)
          puts "  Date in range: yes"

          # Author is not directly available in the teaser, using default
          author = "Nielsen Norman Group"

          # Extract summary
          summary_element = article_node.css('.summary, p')
          summary = summary_element.any? ? summary_element.text.strip : ""

          article_attributes = {
            title: title,
            url: url,
            published_at: published_at,
            source: SOURCE_NAME,
            author: author,
            summary: summary
          }

          articles << save_article(article_attributes)
        rescue => e
          puts "  Error processing article: #{e.message}"
        end
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end

    def fetch_article_content(url)
      response = HTTParty.get(url)
      doc = Nokogiri::HTML(response.body)

      # Try to find the content
      content = doc.css('article .article-content, .article-body, .content').inner_html

      # Try to find the image
      image_url = nil
      image_element = doc.css('article .article-image img, .featured-image img, .hero-image img').first
      image_url = image_element['src'] if image_element

      {
        content: content,
        image_url: image_url
      }
    end
  end
end
