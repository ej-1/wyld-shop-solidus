class CreateFileimports < ActiveRecord::Migration[5.0]
  def change
    create_table :fileimports do |t|

      t.timestamps
    end
  end
end
