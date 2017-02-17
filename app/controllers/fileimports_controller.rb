class FileimportsController < ApplicationController
  before_action :check_if_admin
  before_action :set_fileimport, only: [:show, :edit, :update, :destroy]
  respond_to :html, :xml, :json # NEED TO DECLARE THIS TO USE respond_with
  # http://railscasts.com/episodes/396-importing-csv-and-excel?autoplay=true

  # Takes besides the products attributes either an array of variants or
  # an array of option types.
  #
  # By submitting an array of variants the option types will be created
  # using the *name* key in options hash. e.g
  #
  #   product: {
  #     ...
  #     variants: {
  #       price: 19.99,
  #       sku: "hey_you",
  #       options: [
  #         { name: "size", value: "small" },
  #         { name: "color", value: "black" }
  #       ]
  #     }
  #   }
  #
  # Or just pass in the option types hash:
  #
  #   product: {
  #     ...
  #     option_types: ['size', 'color']
  #   }
  #
  # By passing the shipping category name you can fetch or create that
  # shipping category on the fly. e.g.
  #
  #   product: {
  #     ...
  #     shipping_category: "Free Shipping Items"
  #   }
  #

  def import
    if params[:type_of_upload] == 'Products + properties upload'
      import_products_and_properties(params[:file])
    elsif params[:type_of_upload] == 'Third party store product URL upload'
      import_product_url_for_third_party_store(params[:file])
    else
      redirect_to '/fileimports', notice: "You need to choose a file!"
    end
  end

  def import_product_url_for_third_party_store(file)
    spreadsheet = open_spreadsheet(file)
    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      if row['third_party_product_url'].present? # Is no present when the file cell is empty.
        third_party_product_url = row['third_party_product_url'].strip_html_tags # Removes HTML tags if the it is a HTML link and not a string in the Excel file.
        
        stock_location = Spree::StockLocation.find_by(name: row['store_name'], address1: row['address1'])
        product = Spree::Product.find_by(name: row['name'])
        variants = product.variants # Variants seem to be the unique occurence of a product with a certain set or properties.
        #stock_items = variants.first.stock_items
        stock_items = Spree::StockItem.find_by(variant_id: variants.first.id)
        #store_stock_item = stock_items.find_by(stock_location_id: stock_location.id) # StockItem of the product associated with a specific store_location/store
        store_stock_item = stock_items
        store_stock_item.update_attributes(product_url_for_third_party_store: third_party_product_url, count_on_hand: 1) # TRY TO USE assign_attributes INSTEAD.
        #update_count_on_hand(store_stock_item)
      else
        #update_count_on_hand(store_stock_item)
        store_stock_item.update_attributes(count_on_hand: 1) # TRY TO USE assign_attributes INSTEAD.
        # WHAT IF THERE ARE SEVERAL PRODUCTS WITH THE SAME NAME?
      end
      if !store_stock_item.persisted?
        redirect_to '/fileimports', notice: "Something went wrong! Consult WYLD wikiw or contact CTO!"
      end
    end
    redirect_to '/admin/products', notice: "Products imported."
  end

  def update_count_on_hand(stock_item)
    @stock_item = stock_item
    @stock_item = Spree::StockItem.accessible_by(current_ability, :update).find(stock_item.id)
    @stock_location = @stock_item.stock_location

    count_on_hand_adjustment = 1 # Set this as a fixed value.
    adjustment = count_on_hand_adjustment
    #params[:stock_item].delete(:count_on_hand)
    adjustment -= @stock_item.count_on_hand #if params[:stock_item][:force]

    Spree::StockItem.transaction do
      if @stock_item.update_attributes(:count_on_hand => 1) # PARAMS
        adjust_stock_item_count_on_hand(adjustment)
        #respond_with(@stock_item, status: 200, default_template: :show)
      else
        #invalid_resource!(@stock_item)
      end
    end
  end

  def adjust_stock_item_count_on_hand(count_on_hand_adjustment)
    if @stock_item.count_on_hand + count_on_hand_adjustment < 0
      raise StockLocation::InvalidMovementError.new(Spree.t(:stock_not_below_zero))
    end
    @stock_movement = @stock_location.move(@stock_item.variant, count_on_hand_adjustment, current_api_user)
    @stock_item = @stock_movement.stock_item
  end

  def current_ability # https://github.com/spree/spree/blob/master/core/lib/spree/core/controller_helpers/auth.rb#L52
    @current_ability ||= Spree::Ability.new(try_spree_current_user)
  end

  def try_spree_current_user # https://github.com/spree/spree/blob/master/core/lib/spree/core/controller_helpers/auth.rb
    # This one will be defined by apps looking to hook into Spree
    # As per authentication_helpers.rb
    if respond_to?(:spree_current_user)
      spree_current_user
    # This one will be defined by Devise
    elsif respond_to?(:current_spree_user)
      current_spree_user
    else
      nil
    end
  end



  def import_products_and_properties(file)
    spreadsheet = open_spreadsheet(file)
    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      #product = find_by_id(row["id"]) || new

      sku = row['sku']
      row.delete('sku')
      options_attrs = []
      options = []
      row.keys.each do |key|
        if key.include? 'OPTION='
          formatted_key = key.gsub('OPTION=', '')
          options_attrs.push(formatted_key)
          values = row[key].split(',').each(&:lstrip!) # If there are many values in a cell separated by comma.
          values.each do |value|
            options.push({ name: formatted_key, value: value }.to_h)
          end
          row.delete(key)
        end
      end

      product_attrs = row
      product_attrs["shipping_category_id"] = 1
      product = Spree::Product.new

      variants_attrs = {
        price: 1,
        sku: sku,
        is_master: false # CHECK OUT WHY THIS MATTERS
        #options: options
      }

=begin
      product_attrs = {
        name: "Purple dress 1",
        description: "a nice purple dress",
        available_on: Time.now,
        deleted_at: nil,
        slug: nil,
        meta_description: "purple Dress",
        meta_keywords: "purple dress",
        tax_category_id: nil,
        shipping_category_id: 1,
        created_at: nil,
        updated_at: nil,
        promotionable: nil,
        meta_title: "purple Dress"
      }

       options_attrs = ['size', 'color']

       variants_attrs = {
         price: 1.1,
         sku: "000000000",
         is_master: false,
         options: [
           { name: "size", value: "small" },
           { name: "color", value: "black" }
         ]
       }
=end
      @product = MyProduct.new(product, options_attrs, product_attrs, variants_attrs, options)
      @product = @product.create

      if @product.persisted?
       # THIS PART IS TO ADD PROPERTIES =========START===========


        #respond_with(@product, status: 201, default_template: :show)
        #format.html { redirect_to @product, notice: 'Fileimport was successfully created.' }
        #redirect_to '/fileimports', notice: "Products imported."
      else
        invalid_resource!(@product)
        redirect_to '/fileimports', notice: "Something went wrong! Consult WYLD wikiw or contact CTO!"
      end
    end
    redirect_to '/admin/products', notice: "Products imported."
  end

  def open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::Csv.new(file.path)
    when ".xls" then Roo::Excel.new(file.path)
    when ".xlsx" then Roo::Excelx.new(file.path)
     else raise "Unknown file type: #{file.original_filename}"
    end
  end

  def option_types_params # https://github.com/solidusio/solidus/blob/ba888431a66e646df346ab56bdff6ec2785150a2/api/app/controllers/spree/api/products_controller.rb
    params[:product].fetch(:option_types, [])
  end

  def invalid_resource!(resource) # https://github.com/solidusio/solidus/blob/ba888431a66e646df346ab56bdff6ec2785150a2/api/app/controllers/spree/api/base_controller.rb
    Rails.logger.error "invalid_resouce_errors=#{resource.errors.full_messages}"
    puts "invalid_resouce_errors=#{resource.errors.full_messages}"
    @resource = resource
    render "spree/api/errors/invalid_resource", status: 422
  end

  def set_up_shipping_category
    if shipping_category = params[:product].delete(:shipping_category)
      id = Spree::ShippingCategory.find_or_create_by(name: shipping_category).id
      params[:product][:shipping_category_id] = id
    end
  end

  # GET /fileimports
  # GET /fileimports.json
  def index
    @fileimports = Fileimport.all
  end

  # GET /fileimports/1
  # GET /fileimports/1.json
  def show
  end

  # GET /fileimports/new
  def new
    @fileimport = Fileimport.new
  end

  # GET /fileimports/1/edit
  def edit
  end

  # POST /fileimports
  # POST /fileimports.json
  def create
    @fileimport = Fileimport.new(fileimport_params)

    respond_to do |format|
      if @fileimport.save
        format.html { redirect_to @fileimport, notice: 'Fileimport was successfully created.' }
        format.json { render :show, status: :created, location: @fileimport }
      else
        format.html { render :new }
        format.json { render json: @fileimport.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /fileimports/1
  # PATCH/PUT /fileimports/1.json
  def update
    respond_to do |format|
      if @fileimport.update(fileimport_params)
        format.html { redirect_to @fileimport, notice: 'Fileimport was successfully updated.' }
        format.json { render :show, status: :ok, location: @fileimport }
      else
        format.html { render :edit }
        format.json { render json: @fileimport.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /fileimports/1
  # DELETE /fileimports/1.json
  def destroy
    @fileimport.destroy
    respond_to do |format|
      format.html { redirect_to fileimports_url, notice: 'Fileimport was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    def check_if_admin
      if current_spree_user && Spree::User.find_by(email: current_spree_user.email).has_spree_role?("admin")
      else
        redirect_to '/'
      end
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_fileimport
      @fileimport = Fileimport.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def fileimport_params
      params.fetch(:fileimport, {})
    end
end

class MyProduct # https://github.com/solidusio/solidus/blob/054e4bd75c65166d316f3f63be85efb48736bcdb/core/lib/spree/core/importer/product.rb
  attr_reader :product, :product_attrs, :variants_attrs, :options_attrs, :options

  def initialize(product, options_attrs, product_attrs, variants_attrs, options)
    @options_attrs = options_attrs || []
    @product = Spree::Product.new(product_attrs)
    #@product = product
    @product_attrs=product_attrs
    @variants_attrs = variants_attrs
    @options = options
  end

  def create
    @product.master.price = 1 # THIS IS NEEDED TO MAKE IT WORK.
    if @product.save
      binding.pry
      unique_variant_combinations = []
      keys = options.map{|t| t[:name]}.uniq # ['size', 'color']
      keys.each do |key|
        options.each do |e|
          if e[:name] == key.to_s
            # ['small', 'medium', 'large']
            unique_option = {option: key.to_s, value: e[:value]}
            unique_variant_combinations.push(unique_option)
          end
        end
      end
      binding.pry

      options.each do |option_type|
        binding.pry
        Spree::Variant.find_or_create_by(product_id: @product.id).count
        Spree::Variant.find_or_create_by(product_id: @product.id, is_master: variants_attrs[:is_master], sku: variants_attrs[:sku])
      end
      binding.pry
      #variants_attrs.each do |variant_attribute|        
        #variant_attribute = {variant_attribute[0] => variant_attribute[1]} # ADDED THIS CAUSE OTHERWISE MERGE WOULD BE CALLED ON ARRAY AND NOT A HASH.
        # make sure the product is assigned before the options=
        #product.variants.create({ product: product }.merge(variant_attribute))
      #end

       # options = [{:name=>"size", :value=>"small"}, {:name=>"size", :value=>"medium"}, {:name=>"size", :value=>"large"},{:name=>"color", :value=>"red"},{:name=>"color", :value=>"black"}]
      options.each do |option|
        binding.pry
       # OPTIONS - {:name=>"size", :value=>"small"}
        option_type = Spree::OptionType.find_or_create_by(name: option[:name], presentation: option[:name].capitalize) # size
        option_value = Spree::OptionValue.find_or_create_by(name: option[:value], presentation: option[:value].capitalize, option_type_id: option_type.id) # black
        

        @product.variants.each do |variant|
          Spree::ProductOptionType.find_or_create_by(product_id: @product.id, option_type_id: option_type.id) # variant 1 = color CORRECT



   
          Spree::OptionValuesVariant.find_or_create_by(variant_id: variant.id, option_value_id: option_value.id) # variant 1 = black
        end
       # PROPERTIES
        property = Spree::Property.find_or_create_by(name: option[:name], presentation: option[:name])
        Spree::ProductProperty.find_or_create_by(value: option[:value], product_id: @product.id, property_id: property.id)
      end

      #set_up_options
    end

    product
  end




        #Star wars t-shirt, black, 
        #CREATe option_type "color" UNLESS it exists
        #CREATe option_value "black" UNLESS it exists

        
        #IF no variant exist with the product_id
        #  THEN create variant
        #IF option_values_variants does not exist with the variant_id and option_value_id
        #  THEN create variant
        #  AND CREATE option_values_variants needs to connect variant_id and option_value_id


        #IF no variant exist with the product_id
        #  THEN create variant

        #IF option_values_variants does not exist with the variant_id and option_value_id
        #  THEN create variant
        #  AND CREATE option_values_variants needs to connect variant_id and option_value_id

        #IF product_option_types does not exist with the product_id and option_type_id
        #  THEN create variant
        #  AND CREATE product_option_types needs to connect product_id and option_type_id


  def create_old_method
    product.master.price = 1 # THIS IS NEEDED TO MAKE IT WORK.
    if product.save
        binding.pry
      variants_attrs.each do |variant_attribute|
        binding.pry
        variant_attribute = {variant_attribute[0] => variant_attribute[1]} # ADDED THIS CAUSE OTHERWISE MERGE WOULD BE CALLED ON ARRAY AND NOT A HASH.
        # make sure the product is assigned before the options=
        a = product.variants.create({ product: product }.merge(variant_attribute))
        binding.pry
      end

      set_up_options
    end

    product
  end

  private

  def set_up_options
    options_attrs.each do |name|
      option_type = Spree::OptionType.where(name: name).first_or_initialize do |ot|
        ot.presentation = name
        ot.save!
      end

      unless product.option_types.include?(option_type)
        product.option_types << option_type
      end
    end
  end

end
