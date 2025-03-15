# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  # Remove any authentication-related code

  def index
    @articles = Article.order(published_at: :desc)

    # Apply source filter if provided
    if params[:source].present? && params[:source] != "All Sources"
      @articles = @articles.where(source: params[:source])
    end

    # Apply date range filter if both start and end dates are provided
    if params[:start_date].present? && params[:end_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        @articles = @articles.where(published_at: start_date..end_date)
      rescue ArgumentError => e
        flash.now[:alert] = "Invalid date format. Using default date range."
        # Apply default date range if date parsing fails
        @default_date_filter = true
        @start_date = Date.new(2025, 1, 1)
        @end_date = Date.today
        @articles = @articles.where(published_at: @start_date..@end_date)
      end
    # Default date range when no dates specified
    elsif !params[:start_date].present? && !params[:end_date].present?
      @default_date_filter = true
      @start_date = Date.new(2025, 1, 1)
      @end_date = Date.today

      # IMPORTANT: Actually apply the default filter
      @articles = @articles.where(published_at: @start_date..@end_date)
    else
      # Handle case where only one date is provided
      @default_date_filter = false
      if params[:start_date].present?
        begin
          start_date = Date.parse(params[:start_date])
          @start_date = start_date
          @articles = @articles.where("published_at >= ?", start_date)
        rescue ArgumentError => e
          # Invalid start date format, ignore
        end
      end

      if params[:end_date].present?
        begin
          end_date = Date.parse(params[:end_date])
          @end_date = end_date
          @articles = @articles.where("published_at <= ?", end_date)
        rescue ArgumentError => e
          # Invalid end date format, ignore
        end
      end
    end
