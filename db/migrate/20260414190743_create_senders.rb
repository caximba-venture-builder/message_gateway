class CreateSenders < ActiveRecord::Migration[8.1]
  def change
    create_table :senders, id: :string do |t|
      t.string :phone_number, null: false
      t.string :push_name, null: false
      t.string :os

      t.timestamps
    end

    add_index :senders, :phone_number, unique: true
  end
end
