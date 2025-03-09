# app/services/news_scraper_service.rb
class NewsScraperService
  attr_reader :from_date, :to_date

  def initialize(from_date = Date.new(2025, 1, 1), to_date = Date.today)
    @from_date = from_date
    @to_date = to_date
  end

  def scrape_all
    results = {}

    scrapers.each do |scraper_class|
      begin
        scraper = scraper_class.new(from_date, to_date)
        results[scraper_class.name] = scraper.scrape
      rescue => e
        Rails.logger.error "Error scraping with #{scraper_class.name}: #{e.message}"
        results[scraper_class.name] = { error: e.message }
      end
    end

    results
  end

  def scrape_source(source_name)
    scraper_class = find_scraper_for_source(source_name)

    if scraper_class
      scraper = scraper_class.new(from_date, to_date)
      scraper.scrape
    else
      Rails.logger.error "No scraper found for source: #{source_name}"
      []
    end
  end

  private

  def scrapers
    # Get all classes in the Scrapers module
    scrapers = ObjectSpace.each_object(Class).select { |klass|
      klass.name&.start_with?('Scrapers::') &&
      klass.name != 'Scrapers::BaseScraper' &&
      klass < Scrapers::BaseScraper
    }.to_a

    puts "Available scrapers: #{scrapers.map(&:name)}"

    scrapers
  end

  def find_scraper_for_source(source_name)
    scrapers.find do |scraper_class|
      scraper_class::SOURCE_NAME == source_name
    end
  end
end
