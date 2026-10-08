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

ActiveRecord::Schema[8.1].define(version: 2026_10_08_073800) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analyses", force: :cascade do |t|
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "assessment_choices", force: :cascade do |t|
    t.string "key"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "word_assessments", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "word_id", null: false
    t.datetime "assessed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assessment_choice_id"
    t.index ["analysis_id", "word_id"], name: "index_word_assessments_on_analysis_id_and_word_id", unique: true
    t.index ["analysis_id"], name: "index_word_assessments_on_analysis_id"
    t.index ["assessment_choice_id"], name: "index_word_assessments_on_assessment_choice_id"
    t.index ["word_id"], name: "index_word_assessments_on_word_id"
  end

  create_table "words", force: :cascade do |t|
    t.string "lemma"
    t.string "part_of_speech"
    t.string "dictionary_reading"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lemma", "part_of_speech"], name: "index_words_on_lemma_and_part_of_speech", unique: true
  end

  add_foreign_key "word_assessments", "analyses"
  add_foreign_key "word_assessments", "assessment_choices"
  add_foreign_key "word_assessments", "words"
end
