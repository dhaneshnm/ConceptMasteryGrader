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

ActiveRecord::Schema[8.1].define(version: 2025_11_07_173458) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

# Could not dump table "chunks" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'


  create_table "conversations", force: :cascade do |t|
    t.bigint "course_material_id", null: false
    t.datetime "created_at", null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_material_id"], name: "index_conversations_on_course_material_id"
    t.index ["student_id"], name: "index_conversations_on_student_id"
  end

  create_table "course_materials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_course_materials_on_status"
  end

  create_table "grade_reports", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.text "feedback"
    t.decimal "overall_score", precision: 5, scale: 3
    t.jsonb "scores"
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_grade_reports_on_conversation_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "misconception_patterns", force: :cascade do |t|
    t.string "concept", null: false
    t.bigint "course_material_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "recommended_followups", default: []
    t.jsonb "signal_phrases", default: []
    t.datetime "updated_at", null: false
    t.index ["concept"], name: "index_misconception_patterns_on_concept"
    t.index ["course_material_id"], name: "index_misconception_patterns_on_course_material_id"
    t.index ["signal_phrases"], name: "index_misconception_patterns_on_signal_phrases", using: :gin
  end

  create_table "rubrics", force: :cascade do |t|
    t.string "concept"
    t.bigint "course_material_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "levels"
    t.datetime "updated_at", null: false
    t.index ["course_material_id"], name: "index_rubrics_on_course_material_id"
  end

  create_table "students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "summaries", force: :cascade do |t|
    t.text "content"
    t.bigint "course_material_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_material_id"], name: "index_summaries_on_course_material_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chunks", "course_materials"
  add_foreign_key "conversations", "course_materials"
  add_foreign_key "conversations", "students"
  add_foreign_key "grade_reports", "conversations"
  add_foreign_key "messages", "conversations"
  add_foreign_key "misconception_patterns", "course_materials"
  add_foreign_key "rubrics", "course_materials"
  add_foreign_key "summaries", "course_materials"
end
