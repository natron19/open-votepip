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

ActiveRecord::Schema[8.1].define(version: 2026_10_09_140001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "ai_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "max_output_tokens", default: 2000, null: false
    t.string "model", default: "gemini-2.0-flash", null: false
    t.string "name", null: false
    t.text "notes"
    t.text "system_prompt", null: false
    t.decimal "temperature", precision: 3, scale: 1, default: "0.7"
    t.datetime "updated_at", null: false
    t.text "user_prompt_template", null: false
    t.index ["name"], name: "index_ai_templates_on_name", unique: true
  end

  create_table "clarity_checks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "failure_reason"
    t.text "gemini_raw"
    t.datetime "generated_at"
    t.uuid "proposal_id", null: false
    t.jsonb "reader_questions", default: [], null: false
    t.text "rewritten_motion"
    t.boolean "single_proposal", default: false, null: false
    t.jsonb "split_into", default: [], null: false
    t.string "status", default: "pending", null: false
    t.jsonb "suggested_edits", default: [], null: false
    t.datetime "updated_at", null: false
    t.text "verdict_line"
    t.boolean "votable", default: false, null: false
    t.index ["proposal_id"], name: "index_clarity_checks_on_proposal_id"
    t.index ["status"], name: "index_clarity_checks_on_status"
  end

  create_table "llm_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ai_template_id"
    t.decimal "cost_estimate_cents", precision: 10, scale: 4
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.integer "prompt_token_count"
    t.integer "response_token_count"
    t.string "status", default: "pending", null: false
    t.string "template_name"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["ai_template_id"], name: "index_llm_requests_on_ai_template_id"
    t.index ["created_at"], name: "index_llm_requests_on_created_at"
    t.index ["status"], name: "index_llm_requests_on_status"
    t.index ["user_id"], name: "index_llm_requests_on_user_id"
  end

  create_table "password_resets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.uuid "user_id", null: false
    t.index ["token"], name: "index_password_resets_on_token", unique: true
    t.index ["user_id"], name: "index_password_resets_on_user_id"
  end

  create_table "proposals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "deadline_or_cost"
    t.string "decider", null: false
    t.text "problem", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_proposals_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "clarity_checks", "proposals"
  add_foreign_key "llm_requests", "ai_templates"
  add_foreign_key "llm_requests", "users"
  add_foreign_key "password_resets", "users"
  add_foreign_key "proposals", "users"
end
