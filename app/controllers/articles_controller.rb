class ArticlesController < ApplicationController
  def index
    Rails.logger.debug "DEBUG: All sources in database: #{Article.distinct.pluck(:source)}"
    Rails.logger.debug "DEBUG: Selected sources: #{params[:selected_sources]}"
    Rails.logger.debug "DEBUG: All sources checkbox: #{params[:all_sources]}"

    excluded_sources = ['UX Design Weekly', 'UX Movement']

    @articles = Article.where.not(source: excluded_sources)
                       .order(published_at: :desc)

    # Handle source filtering with checkboxes
    if params[:selected_sources].present? && params[:all_sources] != '1'
      @articles = @articles.where(source: params[:selected_sources])
    end

    # Skip date filtering for UX Planet only when it's the only selected source
    skip_date_filter = (params[:selected_sources].is_a?(Array) &&
                        params[:selected_sources].length == 1 &&
                        params[:selected_sources][0] == "UX Planet")

    unless skip_date_filter
      if params[:start_date].present? && params[:end_date].present?
        begin
          @start_date = Date.parse(params[:start_date])
          @end_date = Date.parse(params[:end_date])
          @articles = @articles.where('published_at >= ?', @start_date.beginning_of_day)
                               .where('published_at <= ?', @end_date.end_of_day)
        rescue ArgumentError => e
          flash.now[:alert] = "Invalid date format. Using default date range."
          @default_date_filter = true
          @start_date = Date.new(2025, 1, 1)
          @end_date = Date.today
          @articles = @articles.where('published_at >= ?', @start_date.beginning_of_day)
                               .where('published_at <= ?', @end_date.end_of_day)
        end
      else
        @default_date_filter = true
        @start_date = Date.new(2025, 1, 1)
        @end_date = Date.today
        @articles = @articles.where('published_at >= ?', @start_date.beginning_of_day)
                             .where('published_at <= ?', @end_date.end_of_day)
      end
    end

    # Calculate total count after filters have been applied
    @total_count = @articles.count
    @earliest_date = @articles.minimum(:published_at)
    @latest_date = @articles.maximum(:published_at)

    @articles = @articles.page(params[:page]).per(20)

    @sources = Article.distinct.pluck(:source)
                      .reject { |source| excluded_sources.include?(source) }
                      .uniq
                      .sort

    Rails.logger.debug "DEBUG: Sources after filtering: #{@sources}"
    Rails.logger.debug "DEBUG: Total articles: #{@total_count}"
    Rails.logger.debug "DEBUG: Filtered articles count: #{@articles.count}"
    Rails.logger.debug "DEBUG: Date range: #{@earliest_date} to #{@latest_date}"
    Rails.logger.debug "DEBUG: SQL Query: #{@articles.to_sql}"
  end

  def show
    @article = Article.find(params[:id])
  end

  def scrape
    if params[:selected_sources].present? && params[:all_sources] != '1'
      # Scrape selected sources
      total = 0
      params[:selected_sources].each do |source|
        articles = NewsScraperService.new.scrape_source(source)
        total += articles.count
      end
      flash[:notice] = "Scraped #{total} articles from selected sources"
    else
      # Scrape all sources
      results = NewsScraperService.new.scrape_all
      total = results.values.flatten.select { |a| a.is_a?(Article) }.count
      flash[:notice] = "Scraped #{total} articles from all sources"
    end

    redirect_to articles_path
  end
end
