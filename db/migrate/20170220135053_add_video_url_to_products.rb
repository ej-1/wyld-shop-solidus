class AddVideoUrlToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :spree_products, :video_url, :string
  end
end
