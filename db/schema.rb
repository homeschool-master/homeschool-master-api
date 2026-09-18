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

ActiveRecord::Schema[7.1].define(version: 2026_09_18_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "calendar_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "teacher_id", null: false
    t.string "title", null: false
    t.text "notes"
    t.string "location"
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.boolean "all_day", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "created_time_zone"
    t.index ["teacher_id", "start_time"], name: "index_calendar_events_on_teacher_id_and_start_time"
    t.index ["teacher_id"], name: "index_calendar_events_on_teacher_id"
  end

  create_table "event_attendees", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "calendar_event_id", null: false
    t.uuid "student_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_event_id", "student_id"], name: "index_event_attendees_on_calendar_event_id_and_student_id", unique: true
    t.index ["calendar_event_id"], name: "index_event_attendees_on_calendar_event_id"
    t.index ["student_id"], name: "index_event_attendees_on_student_id"
  end

  create_table "refresh_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "teacher_id", null: false
    t.string "token", null: false
    t.string "jti", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["jti"], name: "index_refresh_tokens_on_jti", unique: true
    t.index ["teacher_id"], name: "index_refresh_tokens_on_teacher_id"
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
  end

  create_table "students", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "teacher_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "grade_level"
    t.string "color"
    t.string "profile_image_url"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "middle_name"
    t.index ["is_active"], name: "index_students_on_is_active"
    t.index ["teacher_id"], name: "index_students_on_teacher_id"
  end

  create_table "subjects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "teacher_id", null: false
    t.string "name", null: false
    t.string "color"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "teacher_id, lower((name)::text)", name: "index_subjects_on_teacher_id_and_lower_name", unique: true, where: "is_active"
    t.index ["is_active"], name: "index_subjects_on_is_active"
    t.index ["teacher_id"], name: "index_subjects_on_teacher_id"
  end

  create_table "teachers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "nickname"
    t.string "email", null: false
    t.string "phone"
    t.boolean "newsletter_subscribed", default: false
    t.string "password_digest", null: false
    t.string "profile_image_url"
    t.datetime "email_verified_at"
    t.string "email_verification_token"
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pending_email"
    t.string "email_change_token"
    t.datetime "email_change_sent_at"
    t.boolean "notify_account_updates", default: true, null: false
    t.boolean "notify_product_updates", default: true, null: false
    t.boolean "notify_homeschool_resources", default: true, null: false
    t.boolean "onboarding_completed", default: false, null: false
    t.string "middle_name"
    t.string "time_zone"
    t.index ["email"], name: "index_teachers_on_email", unique: true
    t.index ["email_change_token"], name: "index_teachers_on_email_change_token", unique: true
    t.index ["email_verification_token"], name: "index_teachers_on_email_verification_token", unique: true
    t.index ["is_active"], name: "index_teachers_on_is_active"
    t.index ["password_reset_token"], name: "index_teachers_on_password_reset_token", unique: true
  end

  add_foreign_key "calendar_events", "teachers", on_delete: :cascade
  add_foreign_key "event_attendees", "calendar_events", on_delete: :cascade
  add_foreign_key "event_attendees", "students", on_delete: :cascade
  add_foreign_key "refresh_tokens", "teachers"
  add_foreign_key "students", "teachers"
  add_foreign_key "subjects", "teachers"
end
