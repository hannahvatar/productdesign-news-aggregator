# lib/tasks/articles.rake
namespace :articles do
  desc "Generate summaries for articles without good summaries"
  task generate_summaries: :environment do
    puts "Queueing summary generation for articles..."

    # Find articles with missing or short summaries
    articles = Article.where("summary IS NULL OR LENGTH(summary) < 30")
    total_count = articles.count

    puts "Found #{total_count} articles needing summaries."

    # Process in batches to avoid overloading the system
    batch_size = 100
    processed_count = 0

    articles.find_each(batch_size: batch_size) do |article|
      ArticleSummarizationJob.perform_later(article.id)
      processed_count += 1

      if processed_count % 10 == 0
        puts "Queued #{processed_count}/#{total_count} articles..."
      end
    end

    puts "Finished queueing #{processed_count} articles for summary generation."
    puts "Summaries will be generated in the background. Check your app in a while to see them."
  end
end
