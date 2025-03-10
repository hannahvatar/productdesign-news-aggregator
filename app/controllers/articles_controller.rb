# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  # Remove any authentication-related code

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

    # Add some debugging information
    @total_count = @articles.count
    @earliest_date = @articles.minimum(:published_at)
    @latest_date = @articles.maximum(:published_at)

    # Add pagination (20 articles per page)
    # Make sure you have the kaminari gem installed: gem 'kaminari'
    # If using will_paginate, change this to: @articles = @articles.paginate(page: params[:page], per_page: 20)
    @articles = @articles.page(params[:page]).per(20)

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
