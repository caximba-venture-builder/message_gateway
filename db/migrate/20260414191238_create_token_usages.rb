class CreateTokenUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :token_usages, id: :string do |t|
      t.string :sender_id, null: false
      t.string :message_id, null: false
      t.integer :tokens_used, null: false, default: 0
      t.string :model_name

      t.timestamps
    end

    add_index :token_usages, %i[sender_id created_at]
    add_foreign_key :token_usages, :senders, column: :sender_id
    add_foreign_key :token_usages, :messages, column: :message_id
  end
end
