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
    end
  # Default date range when no dates specified
  elsif !params[:start_date].present? && !params[:end_date].present?
    @default_date_filter = true
    @start_date = Date.new(2025, 1, 1)
    @end_date = Date.today

    # IMPORTANT: Actually apply the default filter
    @articles = @articles.where(published_at: @start_date..@end_date)
  end

  # Add debugging information
  @total_count = @articles.count
  @earliest_date = @articles.minimum(:published_at)
  @latest_date = @articles.maximum(:published_at)

  # Add pagination
  @articles = @articles.page(params[:page]).per(20)

  @sources = Article.distinct.pluck(:source).sort
end
