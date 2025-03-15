# lib/scrapers/tldr_newsletter_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class TldrNewsletterScraper < BaseScraper
    SOURCE_NAME = "TLDR Newsletter"

    # You should update this URL for each new newsletter issue
    # This could be automated if you receive the newsletter by email
    # by parsing the email for the "View in browser" link
    CURRENT_ISSUE_URL = "https://a.tldrnewsletter.com/web-version?ep=1&lc=39dbe414-a15c-11ed-bf3a-9b9d338510f2&p=2f531328-00aa-11f0-b677-e3b1b503305a&pt=campaign&t=1741947731&s=c344a0c13f042706991eb3f10c4b699dea42962a83991ffdb049e2905e529056"

    def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
      super(from_date, to_date)
    end

    def scrape
      puts "Starting scrape for: #{SOURCE_NAME}"
      puts "Date range: #{from_date} to #{to_date}"

      response = HTTParty.get(CURRENT_ISSUE_URL)
      puts "Response status: #{response.code}"

      articles = []
      if response.code == 200
        doc = Nokogiri::HTML(response.body)

        # Extract the newsletter date
        date_element = doc.css('.date').first
        newsletter_date = nil

        if date_element
          date_text = date_element.text.strip
          begin
            newsletter_date = parse_date(date_text)
          rescue => e
            puts "Error parsing date: #{e.message}"
            newsletter_date = Date.today
          end
        else
          # Try alternative date formats or default to today
          newsletter_date = Date.today
        end

        puts "Newsletter date: #{newsletter_date}"

        # Only proceed if the newsletter date is within our range
        if within_date_range?(newsletter_date)
          puts "Newsletter date in range, processing articles"

          # Main process to extract articles
          articles = extract_articles(doc, newsletter_date)
        else
          puts "Newsletter date not in range, skipping"
        end
      else
        puts "Failed to fetch newsletter page: #{response.code}"
      end

      puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
      articles
    end

    private

    def extract_articles(doc, newsletter_date)
      articles = []

      # Based on the TLDR Newsletter structure, articles are in these sections
      sections = ['Big Tech & Startups', 'Science & Futuristic Technology',
                  'Programming, Design & Data Science', 'Miscellaneous']

      sections.each do |section|
        section_header = doc.xpath("//h2[contains(text(), '#{section}')]").first
        next unless section_header

        # Find the section container
        section_container = section_header.parent

        # From the TLDR structure, articles are typically in table rows or divs
        # after the section header
        article_elements = section_container.css('.mcnTextContent').select do |element|
          # Look for elements that contain links and don't contain section headers
          element.css('a').any? && element.css('h2').empty?
        end

        article_elements.each do |article_element|
          # Extract article information
          link = article_element.css('a').first
          next unless link

          url = link['href']
          # Skip social media and other non-article links
          next if url.include?('twitter.com') || url.include?('facebook.com') ||
                 url.include?('instagram.com') || url.include?('unsubscribe') ||
                 url.include?('tldrnewsletter.com')

          # Extract title
          title = link.text.strip
          next if title.empty?

          # Extract summary
          # In TLDR, the summary is usually the text after the link
          summary = ""
          current_node = link.next
          while current_node
            if current_node.text?
              summary += current_node.text.strip + " "
            end
            current_node = current_node.next
          end

          # Clean up the summary
          summary = summary.strip

          # Create article
          article_attributes = {
            title: title,
            url: url,
            published_at: newsletter_date,
            source: SOURCE_NAME,
            author: "TLDR Editors",
            summary: summary,
            image_url: nil
          }

          article = save_article(article_attributes)
          articles << article if article

          puts "Extracted article: #{title}"
        end
      end

      articles
    end
  end
end
