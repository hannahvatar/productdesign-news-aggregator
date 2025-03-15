# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  # Remove any authentication-related code

  def index
    # Log initial sources
    Rails.logger.debug "DEBUG: All sources in database: #{Article.distinct.pluck(:source)}"

    # Define excluded sources at the top for easy maintenance
    excluded_sources = ['UX Design Weekly', 'UX Movement']

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
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          @articles = @articles.where(published_at: start_date..end_date)
        rescue ArgumentError => e
          flash.now[:alert] = "Invalid date format. Using default date range."
        end
      end

      # Add default date range if none specified
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

    # Add some debugging information
    @total_count = @articles.count
    @earliest_date = @articles.minimum(:published_at)
    @latest_date = @articles.maximum(:published_at)

    # Add pagination (20 articles per page)
    @articles = @articles.page(params[:page]).per(20)

    # Generate sources, excluding specified sources
    @sources = Article.distinct.pluck(:source)
                      .reject { |source| excluded_sources.include?(source) }
                      .sort

    # Log final sources and article count
    Rails.logger.debug "DEBUG: Sources after filtering: #{@sources}"
    Rails.logger.debug "DEBUG: Total articles: #{@total_count}"
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
