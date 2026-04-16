# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_16_185618) do
  create_table "comments", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "file_path"
    t.integer "line_number"
    t.boolean "posted", default: false, null: false
    t.integer "review_id", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_comments_on_review_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.text "diff_raw"
    t.string "github_token"
    t.integer "pr_number"
    t.json "reading_order"
    t.string "repo_name"
    t.string "repo_owner"
    t.string "status", default: "fetching", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["repo_owner", "repo_name", "pr_number"], name: "index_reviews_on_pr", unique: true
  end

  add_foreign_key "comments", "reviews"
end
