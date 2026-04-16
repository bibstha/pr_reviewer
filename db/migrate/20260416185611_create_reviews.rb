class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.string :repo_owner
      t.string :repo_name
      t.integer :pr_number
      t.string :github_token
      t.string :title
      t.text :body
      t.text :diff_raw
      t.json :reading_order
      t.string :status, null: false, default: "fetching"

      t.timestamps
    end

    add_index :reviews, [:repo_owner, :repo_name, :pr_number], unique: true, name: "index_reviews_on_pr"
  end
end
