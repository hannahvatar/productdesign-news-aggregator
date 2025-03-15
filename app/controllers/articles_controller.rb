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

    # Apply TLDR-specific limiting - safely handle empty article lists
    if params[:tldr_max_articles].present? && params[:tldr_max_articles].to_i > 0
      max_per_day = params[:tldr_max_articles].to_i

      # Get all dates that have TLDR articles
      dates_with_tldr = @articles.where(source: "TLDR Newsletter")
                               .pluck(:published_at)
                               .map(&:to_date)
                               .uniq

      # Only proceed if we have TLDR articles
      if dates_with_tldr.any?
        # Collect article IDs to include
        article_ids_to_include = []

        dates_with_tldr.each do |date|
          # Get IDs of articles for this date, limited to max_per_day
          day_article_ids = @articles.where(source: "TLDR Newsletter")
                                    .where('published_at >= ? AND published_at <= ?',
                                           date.beginning_of_day,
                                           date.end_of_day)
                                    .order(created_at: :desc)
                                    .limit(max_per_day)
                                    .pluck(:id)

          article_ids_to_include.concat(day_article_ids)
        end

        # Apply the filter for TLDR articles only if we have TLDR articles
        if article_ids_to_include.any?
          @articles = @articles.where("(source = 'TLDR Newsletter' AND id IN (?)) OR source != 'TLDR Newsletter'",
                                  article_ids_to_include)
        end
      end
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
    # The scrape method stays as is since it's a POST action
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
