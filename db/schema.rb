# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171017155631) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blank_nodes", force: :cascade do |t|
    t.integer  "work_id"
    t.integer  "class_map_id"
    t.integer  "property_bridge_id"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.string   "property_bridge_ids"
  end

  create_table "class_map_properties", force: :cascade do |t|
    t.string   "property"
    t.string   "label"
    t.boolean  "is_literal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "class_map_property_settings", force: :cascade do |t|
    t.integer  "class_map_id"
    t.integer  "class_map_property_id"
    t.text     "value"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "class_maps", force: :cascade do |t|
    t.integer  "work_id"
    t.string   "map_name"
    t.string   "table_name"
    t.boolean  "enable"
    t.integer  "table_join_id"
    t.integer  "bnode_id"
    t.integer  "er_xpos"
    t.integer  "er_ypos"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "db_connections", force: :cascade do |t|
    t.string   "adapter"
    t.string   "host"
    t.integer  "port"
    t.string   "database"
    t.string   "username"
    t.integer  "work_id"
    t.text     "password"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "namespace_settings", force: :cascade do |t|
    t.integer  "work_id"
    t.integer  "namespace_id"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "namespaces", force: :cascade do |t|
    t.string   "prefix"
    t.string   "uri"
    t.boolean  "is_default"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ontologies", force: :cascade do |t|
    t.integer  "work_id"
    t.text     "ontology"
    t.string   "file_name"
    t.string   "file_format"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "property_bridge_properties", force: :cascade do |t|
    t.string   "property"
    t.string   "label"
    t.boolean  "is_literal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "property_bridge_property_settings", force: :cascade do |t|
    t.integer  "property_bridge_id"
    t.integer  "property_bridge_property_id"
    t.text     "value"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "property_bridge_types", force: :cascade do |t|
    t.string   "symbol"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "property_bridges", force: :cascade do |t|
    t.integer  "work_id"
    t.string   "map_name"
    t.integer  "class_map_id"
    t.boolean  "user_defined"
    t.string   "column_name"
    t.boolean  "enable"
    t.integer  "property_bridge_type_id"
    t.integer  "bnode_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "table_joins", force: :cascade do |t|
    t.integer  "work_id"
    t.integer  "l_table_class_map_id"
    t.integer  "l_table_property_bridge_id"
    t.integer  "r_table_class_map_id"
    t.integer  "r_table_property_bridge_id"
    t.integer  "i_table_class_map_id"
    t.integer  "i_table_l_property_bridge_id"
    t.integer  "i_table_r_property_bridge_id"
    t.integer  "class_map_id"
    t.integer  "property_bridge_id"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "turtle_generations", force: :cascade do |t|
    t.integer  "work_id"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer  "pid"
    t.string   "status"
    t.string   "path"
    t.text     "error_message"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "username"
    t.string   "provider"
    t.string   "uid"
    t.string   "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true, using: :btree
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
    t.index ["username"], name: "index_users_on_username", unique: true, using: :btree
  end

  create_table "works", force: :cascade do |t|
    t.string   "name"
    t.text     "comment"
    t.string   "base_uri"
    t.integer  "user_id"
    t.text     "er_data"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.datetime "mapping_updated"
    t.integer  "license_id"
    t.text     "license"
  end

end
