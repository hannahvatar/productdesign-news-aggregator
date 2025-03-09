class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :url
      t.datetime :published_at
      t.string :source
      t.string :author
      t.text :summary
      t.text :content
      t.string :image_url

      t.timestamps
    end
  end
end
