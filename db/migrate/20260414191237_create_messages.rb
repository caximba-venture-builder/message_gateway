class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages, id: :string do |t|
      t.string :whatsapp_message_id, null: false
      t.string :message_type, null: false
      t.string :sender_id, null: false
      t.integer :message_timestamp, null: false
      t.string :sender_os

      t.timestamps
    end

    add_index :messages, :whatsapp_message_id
    add_index :messages, %i[sender_id message_timestamp]
    add_foreign_key :messages, :senders, column: :sender_id
  end
end
