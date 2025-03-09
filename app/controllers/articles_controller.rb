class ArticlesController < ApplicationController
  #skip_before_action :authenticate_user!, only: [:index, :show, :scrape]

  def index
    @articles = Article.order(published_at: :desc)

    if params[:source].present? && params[:source] != "All Sources"
      @articles = @articles.where(source: params[:source])
    end

    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        @articles = @articles.where(published_at: start_date..end_date)
      rescue ArgumentError => e
        flash.now[:alert] = "Invalid date format. Using default date range."
      end
    end

    @sources = Article.distinct.pluck(:source).sort
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
