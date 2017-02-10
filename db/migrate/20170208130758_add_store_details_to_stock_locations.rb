class AddStoreDetailsToStockLocations < ActiveRecord::Migration[5.0]
  def change
    add_column :spree_stock_locations, :unique_store_id, :integer
    add_column :spree_stock_locations, :url, :string
    add_column :spree_stock_locations, :email, :string
    add_column :spree_stock_locations, :map_coordinates, :string
    add_column :spree_stock_locations, :brick_and_mortar, :boolean
    add_column :spree_stock_locations, :online_store, :boolean
  end
end
