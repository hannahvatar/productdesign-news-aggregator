# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  # Remove any authentication-related code

  def index
    # Log all sources before filtering
    logger.debug "DEBUG: All sources before filtering: #{Article.distinct.pluck(:source)}"

    # Explicitly exclude problematic sources from the start
    excluded_sources = ['UX Movement', 'UX Design Weekly']
    logger.debug "DEBUG: Excluding sources: #{excluded_sources}"

    # Start with all articles, excluding specific sources
    @articles = Article.where.not(source: excluded_sources).order(published_at: :desc)

    # Log remaining sources after source exclusion
    logger.debug "DEBUG: Sources after initial filtering: #{@articles.distinct.pluck(:source)}"

    # Apply source filter if provided
    if params[:source].present? && params[:source] != "All Sources"
      @articles = @articles.where(source: params[:source])
    end

    # Special handling for UX Planet to show all articles regardless of date
    # Only skip date filtering for UX Planet specifically
    skip_date_filter = params[:source] == "UX Planet"

    # Apply date filtering for other sources or when no source filter is applied
    unless skip_date_filter
      if params[:start_date].present? && params[:end_date].present?
        begin
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          @articles = @articles.where(published_at: start_date..end_date)
        rescue ArgumentError => e
          flash.now[:alert] = "Invalid date format. Using default date range."
        end
      end

      # Add default date range if none specified (last 30 days)
      if !params[:start_date].present? && !params[:end_date].present?
        @default_date_filter = true
        @start_date = Date.new(2025, 1, 1)  # Go back to January 1, 2025
        @end_date = Date.today
      else
        @default_date_filter = false
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
        @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
      end
    end

    # Add debugging logs for articles
    logger.debug "DEBUG: Total articles after filtering: #{@articles.count}"
    logger.debug "DEBUG: Article sources after filtering: #{@articles.distinct.pluck(:source)}"

    # Add some debugging information
    @total_count = @articles.count
    @earliest_date = @articles.minimum(:published_at)
    @latest_date = @articles.maximum(:published_at)

    # Add pagination (20 articles per page)
    @articles = @articles.page(params[:page]).per(20)

    # Remove UX Movement and UX Design Weekly from sources
    @sources = Article.distinct.pluck(:source)
               .reject { |source| excluded_sources.include?(source) }
               .sort

    # Final source and count logging
    logger.debug "DEBUG: Final sources in dropdown: #{@sources}"
    logger.debug "DEBUG: Final article count: #{@articles.count}"
  end

  def show
    @article = Article.find(params[:id])
  end

  def scrape
    # Prevent scraping for excluded sources
    excluded_sources = ['UX Movement', 'UX Design Weekly']

    if params[:source].present? && params[:source] != "All Sources"
      # Check if the source is not in excluded sources
      if excluded_sources.include?(params[:source])
        flash[:alert] = "Scraping is not allowed for this source."
        return redirect_to articles_path
      end

      articles = NewsScraperService.new.scrape_source(params[:source])
      flash[:notice] = "Scraped #{articles.count} articles from #{params[:source]}"
    else
      results = NewsScraperService.new.scrape_all(excluded_sources: excluded_sources)
      total = results.values.flatten.select { |a| a.is_a?(Article) }.count
      flash[:notice] = "Scraped #{total} articles from all sources"
    end

    redirect_to articles_path
  end
end
