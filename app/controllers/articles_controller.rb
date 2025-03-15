# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  # Remove any authentication-related code

  def index
    # Log initial sources
    Rails.logger.debug "DEBUG: All sources in database: #{Article.distinct.pluck(:source)}"
    Rails.logger.debug "DEBUG: Selected source: #{params[:source]}"

    # Define excluded sources at the top for easy maintenance
    excluded_sources = ['UX Design Weekly', 'UX Movement']

    # For UX Matters, bypass everything and use a completely different approach
    if params[:source] == "UX Matters"
      # Force eager loading of results with to_a
      @articles_array = Article.where(source: "UX Matters").order(published_at: :desc).to_a

      # Filter by date if needed (manually)
      if params[:start_date].present? && params[:end_date].present?
        begin
          @start_date = Date.parse(params[:start_date])
          @end_date = Date.parse(params[:end_date])

          # Manual date filtering on the Ruby array
          @articles_array = @articles_array.select do |article|
            article_date = article.published_at.to_date
            article_date >= @start_date && article_date <= @end_date
          end
        rescue ArgumentError
          # Handle date parsing errors
          @start_date = Date.new(2025, 1, 1)
          @end_date = Date.today
        end
      else
        @start_date = Date.new(2025, 1, 1)
        @end_date = Date.today
      end

      # Set count information
      @total_count = @articles_array.size
      @earliest_date = @articles_array.min_by(&:published_at)&.published_at
      @latest_date = @articles_array.max_by(&:published_at)&.published_at

      # Manually paginate with Kaminari's array pagination
      page = params[:page].present? ? params[:page].to_i : 1
      page = 1 if page < 1
      @articles = Kaminari.paginate_array(@articles_array).page(page).per(20)

      # Generate sources for dropdown
      @sources = Article.distinct.pluck(:source)
                       .reject { |source| excluded_sources.include?(source) }
                       .uniq.sort
      @sources << "UX Matters" unless @sources.include?("UX Matters")
      @sources.sort!

      # Log information
      Rails.logger.debug "DEBUG: Using array approach for UX Matters, found #{@total_count} articles"
      Rails.logger.debug "DEBUG: Sources after filtering: #{@sources}"
      Rails.logger.debug "DEBUG: Filtered articles count: #{@articles.count}"
      Rails.logger.debug "DEBUG: Date range: #{@earliest_date} to #{@latest_date}"

      return # Skip the rest of the method
    end

    # Normal flow for other sources
    # Start with base query to exclude unwanted sources
    @articles = Article.where.not(source: excluded_sources)
                       .order(published_at: :desc)

    # Apply source filter if provided
    if params[:source].present? && params[:source] != "All Sources"
      @articles = @articles.where(source: params[:source])
    end

    # Special handling for UX Planet to show all articles regardless of date
    skip_date_filter = params[:source] == "UX Planet"

    # Apply date filtering for other sources or when no source filter is applied
    unless skip_date_filter
      if params[:start_date].present? && params[:end_date].present?
        begin
          @start_date = Date.parse(params[:start_date])
          @end_date = Date.parse(params[:end_date])

          # Simple date comparisons
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
        # Default date range
        @default_date_filter = true
        @start_date = Date.new(2025, 1, 1)
        @end_date = Date.today
        @articles = @articles.where('published_at >= ?', @start_date.beginning_of_day)
                           .where('published_at <= ?', @end_date.end_of_day)
      end
    end

    # Add some debugging information
    @total_count = @articles.count
    @earliest_date = @articles.minimum(:published_at)
    @latest_date = @articles.maximum(:published_at)

    # Add pagination (20 articles per page)
    @articles = @articles.page(params[:page]).per(20)

    # Generate sources, excluding specified sources
    @sources = Article.distinct.pluck(:source)
                      .reject { |source| excluded_sources.include?(source) }
                      .uniq
                      .sort

    # Ensure "UX Matters" is in the sources
    @sources << "UX Matters" unless @sources.include?("UX Matters")
    @sources.sort!

    # Log additional debugging information
    Rails.logger.debug "DEBUG: Sources after filtering: #{@sources}"
    Rails.logger.debug "DEBUG: Total articles: #{@total_count}"
    Rails.logger.debug "DEBUG: Filtered articles count: #{@articles.count}"
    Rails.logger.debug "DEBUG: Date range: #{@earliest_date} to #{@latest_date}"

    # Add SQL debugging
    Rails.logger.debug "DEBUG: SQL Query: #{@articles.to_sql}"
  end

  def show
    @article = Article.find(params[:id])
  end

  def scrape
    if params[:source].present? && params[:source] != "All Sources"
      articles = NewsScraperService.new.scrape_source(params[:source])
      flash[:notice] = "Scraped #{articles.count} articles from #{params[:source]}"
    else
      results = NewsScraperService.new.scrape_all
      total = results.values.flatten.select { |a| a.is_a?(Article) }.count
      flash[:notice] = "Scraped #{total} articles from all sources"
    end

    redirect_to articles_path
  end
end
