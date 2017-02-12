class FileimportsController < ApplicationController
  before_action :set_fileimport, only: [:show, :edit, :update, :destroy]

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
