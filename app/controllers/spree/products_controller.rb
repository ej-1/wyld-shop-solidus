require 'pry'
module Spree
  class ProductsController < Spree::StoreController
    before_action :load_product, only: :show
    before_action :load_taxon, only: :index

    rescue_from ActiveRecord::RecordNotFound, with: :render_404
    helper 'spree/taxons'

    respond_to :html

    def index
      @searcher = build_searcher(params.merge(include_images: true))
      @products = @searcher.retrieve_products
      @taxonomies = Spree::Taxonomy.includes(root: :children)
    end

    def show
      @taxonomies = Spree::Taxonomy.includes(root: :children)
      variant = Spree::Variant.find_by(product_id: @product.id)
      stock_items = Spree::StockItem.where("variant_id = #{variant.id} AND count_on_hand > 0") # Can e.g. be 1 red dress in store A and 0-2 red dresses in store B.

      if stock_items
        @online_stores = []
        stock_items.each do |stock_item|
          store = Spree::StockLocation.where(id: stock_item.stock_location_id, online_store: true).first
          store_and_product_url_for_third_party_store = [store, stock_item.product_url_for_third_party_store]
          if store then @online_stores << store_and_product_url_for_third_party_store end
        end

        @brick_and_mortar_stores = []
        stock_items.each do |stock_item|
          store = Spree::StockLocation.where(id: stock_item.stock_location_id, brick_and_mortar: true).first
          store_and_product_url_for_third_party_store = [store, stock_item.product_url_for_third_party_store]
          if store then @brick_and_mortar_stores << store_and_product_url_for_third_party_store end
        end

        #@online_stores = stock_items.map { |stock_item| Spree::StockLocation.where(id: stock_item.stock_location_id, online_store: true) }
        #@brick_and_mortar_stores = stock_items.map { |stock_item| Spree::StockLocation.where(id: stock_item.stock_location_id, brick_and_mortar_store: true) }
      else
      end

      @variants = @product.
        variants_including_master.
        display_includes.
        with_prices(current_pricing_options).
        includes([:option_values, :images])

      @product_properties = @product.product_properties.includes(:property)
      @taxon = Spree::Taxon.find(params[:taxon_id]) if params[:taxon_id]

      @markers = @brick_and_mortar_stores.map do |store, product_url_for_third_party_store|
      #@markers = ListItem.where(list_id: params[:id]).all.map do |list_item| # Create hash of marker coordinates for list items.
        adress = store.map_coordinates.split(",")
         {


           lat: adress[0],
           lng: adress[1],
           title: store.name,
           store_url: store.url,
           store_address1: store.address1,
           store_address2: store.address2,
           store_zipcode: store.zipcode,
           store_city: store.city,
           store_phone: store.phone,
           store_email: store.email,
           desc: "",
           id: store.id
         }
      end
      respond_to do |format|
        format.html
        format.json { render json: @markers }
      end
    end

    private

    def accurate_title
      if @product
        @product.meta_title.blank? ? @product.name : @product.meta_title
      else
        super
      end
    end

    def load_product
      if try_spree_current_user.try(:has_spree_role?, "admin")
        @products = Spree::Product.with_deleted
      else
        @products = Spree::Product.available
      end
      @product = @products.friendly.find(params[:id])
    end

    def load_taxon
      @taxon = Spree::Taxon.find(params[:taxon]) if params[:taxon].present?
    end
  end
end