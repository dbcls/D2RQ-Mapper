require 'togo_mapper/connection'
require 'togo_mapper/mapping'

class WorksController < ApplicationController
  class InvalidFormValue < StandardError; end

  include ActionView::Helpers::TextHelper
  include TogoMapper::Connection
  include TogoMapper::Mapping

  protect_from_forgery except: :er_data
  before_action :authenticate_user!, :set_html_body_class

  def index
  end


  def create
    begin
      setup_new_mapping
      flash[:msg] = 'New mapping was successfully created.'
      redirect_to edit_work_url(@work)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, InvalidFormValue
      handle_validation_error
      @work = Work.new(work_params)
      @db_connection = DbConnection.new(db_connection_params)
      @works = Work.for_menu(current_user.id)
      render action: 'new'
    rescue => e
      logger.fatal e.inspect
      logger.fatal e.backtrace.join("\n")
      err_msg = e.message.force_encoding("UTF-8")
      err_msg = err_msg.scrub('?')
      flash.now[:err] = err_msg
      @work = Work.new(work_params)
      @db_connection = DbConnection.new(db_connection_params)
      @works = Work.for_menu(current_user.id)
      render action: 'new'
    end
  end


  def new
    set_instance_variables
  end


  def edit
    set_instance_variables
  end


  def show
  end


  def update
    @work = Work.find(params[:id])
    validate_user(@work.id)

    begin
      ActiveRecord::Base.transaction do
        @work.update!(work_params)

        @db_connection = DbConnection.find(db_connection_params[:id])
        @db_connection.update!(db_connection_params)

        # Connect to the database ?
        TogoMapper::DB.new(@db_connection.connection_config)
      end

      flash[:msg] = 'Mapping was successfully updated.'
      redirect_to edit_work_url(@work)
    rescue ActiveSupport::MessageVerifier::InvalidSignature => e
      handle_validation_error
      @works = Work.where(user_id: current_user.id)
      render action: 'edit'
    rescue => e
      logger.fatal e.inspect
      logger.fatal e.backtrace.join("\n")
      flash.now[:err] = e.message.force_encoding("UTF-8")
      @works = Work.for_menu(current_user.id)
      render action: 'edit'
    end
  end


  def destroy
    work = Work.find(params[:id])
    validate_user(work.id)

    begin
      ActiveRecord::Base.transaction do
        work.destroy
      end
      set_work_id_to_session(nil)
      flash[:msg] = "Mapping was successfully deleted."
      redirect_to new_work_url
    rescue => e
      logger.fatal e.inspect
      logger.fatal e.backtrace.join("\n")
      flash[:err] = "Sorry, system error has occurred."
      redirect_to edit_work_url(params[:id])
    end
  end


  def er_data
    validate_user
    
    json = JSON.parse(params[:json])
    json.each do |table|
      class_map = ClassMap.find(table['id'])
      class_map.er_xpos = table['x']
      class_map.er_ypos = table['y']
      class_map.save!
    end

    if !params.key?(:echo_message) || params[:echo_message] == "true"
      @status = 'success'
      @message = 'ER diagram data has been saved successfully.'
    end
  end

  private

  def setup_new_mapping
    success = true

    ActiveRecord::Base.transaction do
      @work = Work.new(work_params)
      success &= @work.save

      @db_connection = DbConnection.new(
        db_connection_params.merge(work_id: @work.id)
      )
      success &= @db_connection.save

      raise InvalidFormValue unless success

      Namespace.default_ns.each do |ns|
        NamespaceSetting.create!(work_id: @work.id, namespace_id: ns.id)
      end

      init_mapping(@db_connection)

      @work.mapping_updated = Time.now
      @work.save!
    end

    success
  end


  def set_instance_variables
    @works = Work.for_menu(current_user.id)
    if params.key?(:id)
      validate_user
      @work = Work.find(params[:id])
      @db_connection = DbConnection.where(work_id: @work.id).first
    else
      @work = Work.new
      @work.user_id = current_user.id
      @db_connection = DbConnection.new
    end
  end


  def handle_validation_error
    num_errors = @work.errors.count + @db_connection.errors.count
    err_msgs = []
    @work.errors.full_messages.each do |msg|
      err_msgs << "#{msg}"
    end
    @db_connection.errors.full_messages.each do |msg|
      err_msgs << "#{msg}"
    end
    flash.now[:err] = %Q!#{pluralize(num_errors, "error")} prohibited this setting from being saved.<br />#{err_msgs.map{ |s| "#{s}<br />" }.join }!
  end


  def work_params
    params.require(:work).permit(:name, :comment, :user_id, :base_uri, :licence_subject_uri, :license_id, :license)
  end


  def db_connection_params
    params.require(:db_connection).permit(
      :id,
      :adapter,
      :database,
      :host,
      :port,
      :username,
      :password,
      :work_id
    )
  end


  def set_html_body_class
    @html_body_class = 'page-set'
  end

end
