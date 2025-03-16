# app/jobs/article_summarization_job.rb
class ArticleSummarizationJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article

    ArticleSummarizerService.new.summarize(article)
  end
end
