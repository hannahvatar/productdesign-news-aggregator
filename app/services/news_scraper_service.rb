# app/services/news_scraper_service.rb
class NewsScraperService
  EXCLUDED_SOURCES = ['UX Movement', 'UX Design Weekly']

  def scrape_all
    scrapers = [
      Scrapers::SmashingMagazineScraper,
      Scrapers::NnGroupScraper,
      Scrapers::FigmaBlogScraper,
      Scrapers::UxPlanetScraper,
      Scrapers::UxMattersScraper,
      Scrapers::UxCollectiveScraper,
      Scrapers::DepartmentOfProductScraper,
      Scrapers::TldrApiScraper,
      Scrapers::FigmaReleaseNotesScraper,
      Scrapers::PrototyprScraper
    ]

    results = {}
    scrapers.each do |scraper_class|
      source_name = scraper_class.const_get(:SOURCE_NAME)
      next if EXCLUDED_SOURCES.include?(source_name)

      begin
        scraper = scraper_class.new
        results[source_name] = scraper.scrape
      rescue => e
        Rails.logger.error "Error scraping #{source_name}: #{e.message}"
      end
    end

    results
  end

  def scrape_source(source_name)
    scraper_class = find_scraper_for_source(source_name)
    return [] unless scraper_class

    scraper = scraper_class.new
    scraper.scrape
  end

  private

# In app/services/news_scraper_service.rb
def find_scraper_for_source(source_name)
  scraper_classes = [
    Scrapers::SmashingMagazineScraper,
    Scrapers::NnGroupScraper,
    Scrapers::FigmaBlogScraper,
    Scrapers::UxPlanetScraper,
    Scrapers::UxMattersScraper,
    Scrapers::UxCollectiveScraper,
    Scrapers::DepartmentOfProductScraper,
    Scrapers::TldrApiScraper,
    Scrapers::FigmaReleaseNotesScraper,
    Scrapers::PrototyprScraper
  ]

  scraper_classes.find { |klass| klass.const_get(:SOURCE_NAME) == source_name }
end
end
