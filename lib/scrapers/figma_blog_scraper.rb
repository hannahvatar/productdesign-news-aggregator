# lib/scrapers/figma_blog_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class FigmaBlogScraper < BaseScraper
    SOURCE_NAME = "Figma Blog"
    BASE_URL = "https://www.figma.com/blog/"

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      response = HTTParty.get(BASE_URL)
      puts "Response status: #{response.code}"
      doc = Nokogiri::HTML(response.body)

      articles = []

      # Process regular blog text cards
      puts "Processing blog text cards..."
      doc.css('.blog-text-card').each do |article_node|
        article = process_article_node(article_node)
        articles << article if article
      end

      # Process other article formats (like the storyteller article)
      puts "Processing other article formats..."
      main = doc.css('main').first
      if main
        # Find all links that might be articles
        main.css('a').each do |link|
          # Skip links that are already within blog text cards
          next if link.ancestors.any? { |a| a['class'] && a['class'].include?('blog-text-card') }

          # Check if this link contains an article title and date
          link_text = link.text.strip

          # Only process links that have substantial text and look like article links
          if link_text.length > 30 && link['href'] && link['href'].include?('/blog/')
            puts "Found potential article link: #{link_text[0..50]}..."

            # Try to extract title and date
            title_match = link_text.match(/^(.+?)(?:January|February|March|April|May|June|July|August|September|October|November|December)/i)
            date_match = link_text.match(/(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}/i)

            if title_match && date_match
              title = title_match[1].strip
              date_str = date_match[0]

              # Extract the rest as potentially the summary
              summary_text = link_text.sub(title, '').sub(date_str, '')
              summary = summary_text.sub(/^By\s+[^.]+\.?\s*/i, '').strip

              # Extract author if present
              author_match = summary_text.match(/By\s+([^.]+)\.?\s*/i)
              author = author_match ? author_match[1].strip : "Figma Team"

              url = link['href']
              url = "https://www.figma.com#{url}" unless url.start_with?('http')

              puts "Processing article: #{title}"
              puts "  Date string: '#{date_str}'"

              published_at = parse_date(date_str)
              puts "  Parsed date: #{published_at}"

              next unless within_date_range?(published_at)
              puts "  Date in range: yes"

              article_attributes = {
                title: title,
                url: url,
                published_at: published_at,
                source: SOURCE_NAME,
                author: author,
                summary: summary,
                image_url: nil
              }

              articles << save_article(article_attributes)
            end
          end
        end
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end

    private

    def process_article_node(article_node)
      begin
        # Extract title
        title_element = article_node.css('h3, h2, .title').first
        return nil unless title_element
        title = title_element.text.strip

        # Extract URL
        link_element = article_node.css('a').first
        return nil unless link_element
        url = link_element['href']
        url = "https://www.figma.com#{url}" unless url.start_with?('http')

        puts "Processing article: #{title}"

        # Extract date
        date_elements = article_node.css('.date, time, .meta, .published')
        date_str = date_elements.first&.text&.strip

        if !date_str || date_str.empty?
          # Try to find date in parent elements
          parent = article_node.parent
          date_elements = parent.css('.date, time, .meta, .published')
          date_str = date_elements.first&.text&.strip
        end

        puts "  Date string: '#{date_str}'"

        if !date_str || date_str.empty?
          # If we still can't find a date, default to today
          puts "  No date found, using today's date"
          published_at = Date.today
        else
          published_at = parse_date(date_str)
        end

        puts "  Parsed date: #{published_at}"

        return nil unless within_date_range?(published_at)
        puts "  Date in range: yes"

        # Extract author - might not be present
        author_element = article_node.css('.author, .byline')
        author = author_element.first&.text&.strip || "Figma Team"

        # Extract summary
        summary_element = article_node.css('p, .excerpt, .description')
        summary = summary_element.first&.text&.strip || ""

        # Extract image URL if present
        image_element = article_node.css('img')
        image_url = image_element.first&.[]('src')

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
