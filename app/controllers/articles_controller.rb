# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  # Remove any authentication-related code

  def index
    # Log initial sources
    Rails.logger.debug "DEBUG: All sources in database: #{Article.distinct.pluck(:source)}"
    Rails.logger.debug "DEBUG: Selected source: #{params[:source]}"

    # Define excluded sources at the top for easy maintenance
    excluded_sources = ['UX Design Weekly', 'UX Movement']

    # Start with base query to exclude unwanted sources
    @articles_query = Article.where.not(source: excluded_sources)

    # Special case for UX Matters - use direct approach
    if params[:source] == "UX Matters"
      # Get UX Matters articles directly by ID
      ux_matters_ids = Article.where(source: "UX Matters").pluck(:id)

      # Apply date filtering if needed
      if params[:start_date].present? && params[:end_date].present?
        begin
          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])

          # Use simplified date query on these specific articles
          @articles_query = Article.where(id: ux_matters_ids)
                                  .where("CAST(published_at AS DATE) BETWEEN ? AND ?", start_date, end_date)
        rescue ArgumentError => e
          flash.now[:alert] = "Invalid date format. Using default date range."
          @articles_query = Article.where(id: ux_matters_ids)
        end
      else
        @articles_query = Article.where(id: ux_matters_ids)
      end

      # Set date variables
      @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.new(2025, 1, 1)
      @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
    else
      # Normal flow for other sources
      # Apply source filter if provided
      if params[:source].present? && params[:source] != "All Sources"
        @articles_query = @articles_query.where(source: params[:source])
      end

      # Special handling for UX Planet to show all articles regardless of date
      skip_date_filter = params[:source] == "UX Planet"

      # Apply date filtering for other sources or when no source filter is applied
      unless skip_date_filter
        if params[:start_date].present? && params[:end_date].present?
          begin
            start_date = Date.parse(params[:start_date])
            end_date = Date.parse(params[:end_date])

            # Use BETWEEN with date casting for better compatibility
            @articles_query = @articles_query.where("CAST(published_at AS DATE) BETWEEN ? AND ?", start_date, end_date)

            @start_date = start_date
            @end_date = end_date
          rescue ArgumentError => e
            flash.now[:alert] = "Invalid date format. Using default date range."
            @default_date_filter = true
          end
        end

        # Add default date range if none specified
        if !params[:start_date].present? && !params[:end_date].present?
          @default_date_filter = true
          @start_date = Date.new(2025, 1, 1)  # Go back to January 1, 2025
          @end_date = Date.today

          # Apply default date filter
          @articles_query = @articles_query.where("CAST(published_at AS DATE) BETWEEN ? AND ?", @start_date, @end_date)
        end
      end
    end

    # Log SQL before ordering and pagination
    Rails.logger.debug "DEBUG: SQL before order: #{@articles_query.to_sql}"

    # Add ordering
    @articles_query = @articles_query.order(published_at: :desc)

    # Calculate totals before pagination
    @total_count = @articles_query.count
    @earliest_date = @articles_query.minimum(:published_at)
    @latest_date = @articles_query.maximum(:published_at)

    # Add pagination (20 articles per page)
    @articles = @articles_query.page(params[:page]).per(20)

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
    Rails.logger.debug "DEBUG: Final SQL Query: #{@articles.to_sql}"
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
