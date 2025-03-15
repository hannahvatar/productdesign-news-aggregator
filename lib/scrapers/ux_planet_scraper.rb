def scrape
  puts "Starting scrape for: #{SOURCE_NAME}"
  articles = []

  # First try the RSS feed for most recent articles
  feed_articles = scrape_rss
  articles.concat(feed_articles)

  # If we need older articles (based on date range), scrape the website
  if from_date < (Date.today - 7)
    puts "Scraping website for older articles..."
    website_articles = scrape_website
    articles.concat(website_articles)
  end

  puts "Saved #{articles.count} articles from #{SOURCE_NAME}"
  articles
end

def scrape_rss
  # Your existing RSS scraping code
end

def scrape_website
  articles = []
  # Start from the first page
  page = 1
  continue_scraping = true

  while continue_scraping && page <= 10 # Limit to first 10 pages to avoid excessive requests
    url = "https://uxplanet.org/latest?page=#{page}"
    puts "Scraping page #{page}: #{url}"

    response = HTTParty.get(url)
    if response.code == 200
      doc = Nokogiri::HTML(response.body)

      # Find article elements on the page
      article_elements = doc.css('article')

      # If no articles found or all articles are older than our from_date, stop scraping
      if article_elements.empty?
        puts "No more articles found"
        break
      end

      article_elements.each do |article_element|
        # Extract article details
        title_element = article_element.css('h3').first
        next unless title_element

        title = title_element.text.strip
        link = title_element.css('a').first['href'] rescue nil
        next unless link

        # Make sure the URL is absolute
        url = link.start_with?('http') ? link : "https://uxplanet.org#{link}"

        # Extract date
        date_element = article_element.css('time').first
        date_str = date_element ? date_element['datetime'] : nil
        published_at = date_str ? Time.parse(date_str).to_date : nil

        # Skip if no date or outside range
        next unless published_at
        next unless within_date_range?(published_at)

        # Extract author
        author_element = article_element.css('.author').first
        author = author_element ? author_element.text.strip : "UX Planet"

        # Extract summary
        summary_element = article_element.css('p').first
        summary = summary_element ? summary_element.text.strip : ""

        article_attributes = {
          title: title,
          url: url,
          published_at: published_at,
          source: SOURCE_NAME,
          author: author,
          summary: summary
        }

        articles << save_article(article_attributes)
      end

      # Check if we found any articles in the date range
      oldest_date = articles.map(&:published_at).min
      if oldest_date && oldest_date < from_date
        puts "Reached articles older than requested date range"
        continue_scraping = false
      else
        page += 1
      end
    else
      puts "Failed to fetch page #{page}: #{response.code}"
      break
    end
  end

  articles
end
