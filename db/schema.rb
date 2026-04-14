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

ActiveRecord::Schema[8.1].define(version: 2026_04_14_191939) do
  create_table "concatenation_buffers", id: :string, force: :cascade do |t|
    t.text "accumulated_text", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "instance_name", null: false
    t.integer "message_count", default: 0, null: false
    t.string "sender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_concatenation_buffers_on_expires_at"
    t.index ["sender_id", "instance_name"], name: "idx_concat_buf_sender_instance", unique: true
  end

  create_table "messages", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "message_timestamp", null: false
    t.string "message_type", null: false
    t.string "sender_id", null: false
    t.string "sender_os"
    t.datetime "updated_at", null: false
    t.string "whatsapp_message_id", null: false
    t.index ["sender_id", "message_timestamp"], name: "index_messages_on_sender_id_and_message_timestamp"
    t.index ["whatsapp_message_id"], name: "index_messages_on_whatsapp_message_id"
  end

  create_table "senders", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "os"
    t.string "phone_number", null: false
    t.string "push_name", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_number"], name: "index_senders_on_phone_number", unique: true
  end

  create_table "token_usages", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_id", null: false
    t.string "sender_id", null: false
    t.integer "tokens_used", default: 0, null: false
    t.string "transcription_model"
    t.datetime "updated_at", null: false
    t.index ["sender_id", "created_at"], name: "index_token_usages_on_sender_id_and_created_at"
  end

  add_foreign_key "concatenation_buffers", "senders"
  add_foreign_key "messages", "senders"
  add_foreign_key "token_usages", "messages"
  add_foreign_key "token_usages", "senders"
end
