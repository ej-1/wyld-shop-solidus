class AddProductUrlForThirdPartyStoreToStockItems < ActiveRecord::Migration[5.0]
  def change
    add_column :spree_stock_items, :product_url_for_third_party_store, :string
  end
end
