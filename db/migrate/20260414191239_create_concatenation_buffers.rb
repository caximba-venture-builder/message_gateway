class CreateConcatenationBuffers < ActiveRecord::Migration[8.1]
  def change
    create_table :concatenation_buffers, id: :string do |t|
      t.string :sender_id, null: false
      t.string :instance_name, null: false
      t.text :accumulated_text, null: false, default: ""
      t.datetime :expires_at, null: false
      t.integer :message_count, null: false, default: 0

      t.timestamps
    end

    add_index :concatenation_buffers, :expires_at
    add_index :concatenation_buffers, %i[sender_id instance_name], unique: true, name: "idx_concat_buf_sender_instance"
    add_foreign_key :concatenation_buffers, :senders, column: :sender_id
  end
end
