class AddContentFetchedAndIndexesToArticles < ActiveRecord::Migration[7.1]
  def change
    # Add the content_fetched boolean field with default false
    add_column :articles, :content_fetched, :boolean, default: false, null: false

    # Add important indexes for performance
    add_index :articles, :url, unique: true
    add_index :articles, :published_at
    add_index :articles, :source
  end
end
