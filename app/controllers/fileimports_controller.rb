class FileimportsController < ApplicationController
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
      product = Spree::Product.new

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
      #options = { variants_attrs: variants_params, options_attrs: option_types_params }
      #@product = Spree::Core::Importer::Product.new(product_params, options)
      #binding.pry

      @product = MyProduct.new(product, options_attrs, product_attrs, variants_attrs)
      @product = @product.create

      if @product.persisted?
        #respond_with(@product, status: 201, default_template: :show)
        #format.html { redirect_to @product, notice: 'Fileimport was successfully created.' }
        redirect_to '/fileimports', notice: "Products imported."
      else
        invalid_resource!(@product)
        redirect_to '/fileimports', notice: "Something went wrong! Contact CTO!"
      end
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
    # Use callbacks to share common setup or constraints between actions.
    def set_fileimport
      @fileimport = Fileimport.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def fileimport_params
      params.fetch(:fileimport, {})
    end
end

class MyProduct
  attr_reader :product, :product_attrs, :variants_attrs, :options_attrs

  def initialize(product, options_attrs, product_attrs, variants_attrs)
    @options_attrs=options_attrs
    @product=Spree::Product.new(product_attrs)
    #@product = product
    @product_attrs=product_attrs
    @variants_attrs=variants_attrs
  end

  def create

    product.master.price = 1 # THIS IS NEEDED TO MAKE IT WORK.
    if product.save
      variants_attrs.each do |variant_attribute|
        variant_attribute = {variant_attribute[0] => variant_attribute[1]} # ADDED THIS CAUSE OTHERWISE MERGE WOULD BE CALLED ON ARRAY AND NOT A HASH.
        # make sure the product is assigned before the options=
        product.variants.create({ product: product }.merge(variant_attribute))
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
