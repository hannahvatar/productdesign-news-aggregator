# app/services/article_summarizer_service.rb
require 'openai'

class ArticleSummarizerService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV["OPENAI_API_KEY"]
    )
  end

  def summarize(article)
    # Skip if already has a good summary
    return article.summary if article.summary.present? && article.summary.length > 30

    title = article.title
    source = article.source

    prompt = "Create a concise 1-2 sentence summary of this article titled '#{title}' from #{source}."
    if article.summary.present?
      prompt += " Existing description: #{article.summary}"
    end

    begin
      response = @client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: "You are a helpful assistant that creates concise article summaries for a product design news aggregator." },
            { role: "user", content: prompt }
          ],
          max_tokens: 100,
          temperature: 0.7
        }
      )

      summary = response.dig("choices", 0, "message", "content")

      if summary.present?
        article.update(summary: summary)
      end

      return summary
    rescue => e
      Rails.logger.error "Error summarizing article #{article.id}: #{e.message}"
      return article.summary
    end
  end
end
