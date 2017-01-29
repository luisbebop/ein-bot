class CreateUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :users do |t|
      t.string  :name
      t.string  :picture
      t.integer :scoped_id, :limit => 8
      t.string  :xpub
      t.string  :nickname
      t.string  :chat_context
    end
  end
end
