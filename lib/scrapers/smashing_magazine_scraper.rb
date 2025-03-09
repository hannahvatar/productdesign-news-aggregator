# For lib/scrapers/smashing_magazine_scraper.rb
require_relative 'base_scraper'

module Scrapers
  class SmashingMagazineScraper < BaseScraper
    SOURCE_NAME = "Smashing Magazine UX"
    BASE_URL = "https://www.smashingmagazine.com/category/user-experience/"

    def scrape
      response = HTTParty.get(BASE_URL)
      doc = Nokogiri::HTML(response.body)

      articles = []

      doc.css('article.article--post').each do |article_node|
        title = article_node.css('h2.article__title a').text.strip
        url = article_node.css('h2.article__title a').attr('href').to_s

        # Extract date
        date_str = article_node.css('.article__meta time').attr('datetime').to_s
        published_at = parse_date(date_str)

        next unless within_date_range?(published_at)

        author = article_node.css('.article__author-name').text.strip
        summary = article_node.css('.article__teaser').text.strip
        image_url = article_node.css('.article__image img').attr('src')&.to_s

        article_attributes = {
          title: title,
          url: url,
          published_at: published_at,
          source: SOURCE_NAME,
          author: author,
          summary: summary,
          image_url: image_url
        }

        articles << save_article(article_attributes)
      end

      articles
    end
  end
end
