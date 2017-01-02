class CreateBooks < ActiveRecord::Migration[5.0]
  def change
    create_table :books do |t|
      t.string :code, null: false
      t.string :title, null: false
      t.string :author
      t.string :publisher
      t.timestamps
    end
  end
end
