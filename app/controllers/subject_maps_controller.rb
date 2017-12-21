require 'nokogiri'
require 'togo_mapper/mapping'

class SubjectMapsController < ApplicationController
  include TogoMapper::Mapping

  before_action :authenticate_user!, :set_html_body_class

  def index
  end

  def show
    work_id = params[:id]
    validate_user(work_id)

    begin
      @work = Work.find(work_id)

      maintain_consistency_with_rdb
      
      if params[:db_conn_id]
        db_conn = DbConnection.find(params[:db_conn_id])
      else
        db_conn = DbConnection.where(work_id: @work.id).first
      end

      @database = db_conn.database
      set_instance_variables_for_table_and_column(db_conn)

      @table_joins = TableJoin.by_work_id(@work.id)

      @table_join = TableJoin.new
      @table_join.work_id = @work.id
      unless @class_maps.empty?
        @table_join.l_table_class_map_id = @class_maps[0].id
        @table_join.l_table_property_bridge_id = @property_bridges[@class_maps[0].id][0].id
        @table_join.i_table_class_map_id = nil
        @table_join.i_table_l_property_bridge_id = nil
        @table_join.i_table_r_property_bridge_id = nil
        @table_join.r_table_class_map_id = @class_maps[0].id
        @table_join.r_table_property_bridge_id = @property_bridges[@class_maps[0].id][0].id
      end

      @blank_nodes = BlankNode.where(work_id: work_id)
    rescue => e
      logger.fatal e.inspect
      logger.fatal e.backtrace.join("\n")
      flash[:error] = e.message.force_encoding("UTF-8")
      redirect_to :menu
    end
  end


  def create
  end


  def new
  end


  def edit
  end


  def update
    respond_to do |format|
      format.js {
        begin
          @class_map = ClassMap.find(params[:id])
          validate_user(@class_map.work_id)
          @class_map.update(class_map_params)
          @work = Work.find(@class_map.work_id)
          save_mapping_updated_time
        rescue => e
          logger.fatal e.inspect
          logger.fatal e.backtrace.join("\n")
          render 'update_error'
        end
      }
    end
  end


  def destroy
  end

  
  def records
    @class_map = ClassMap.find(params[:id])
    @db_connection = @class_map.work.db_connection
    @exmaple_records_table_name = @class_map.table_name
    db_client = TogoMapper::DB.new(@db_connection.connection_config)
    @columns = db_client.columns(@exmaple_records_table_name)
    @records = db_client.records(@exmaple_records_table_name, 0, EXAMPLE_RECORDS_MAX_ROWS)
    db_client.close

    if xhr?
      set_headers_for_cross_domain
      response_record_json
    else
      render 'records', layout: 'records'
    end
  end

  private

  def set_instance_variables_for_table_and_column(db_conn)
    db_client = TogoMapper::DB.new(db_conn.connection_config)

    @table_names = db_client.tables.sort
    @column_names = {}

    @class_maps = []
    @property_bridges = {}

    @table_names.each do |table_name|
      columns = db_client.columns(table_name)

      class_map = ClassMap.where(work_id: @work.id, table_name: table_name).first
      unless class_map
        class_map = init_mapping_for_table(table_name, columns)
      end
      @class_maps << class_map
      @property_bridges[class_map.id] = []

      columns.each do |column|
        property_bridge = PropertyBridge.where(class_map_id: class_map.id, column_name: column).first
        unless property_bridge
          property_bridge = init_mapping_for_column(class_map, table_name, column)
        end
        @property_bridges[class_map.id] << property_bridge
      end

      @column_names[table_name] = columns
    end

    db_client.close
  end


  def set_html_body_class
    @html_body_class = 'page-tables'
  end


  def class_map_params
    params.require(:class_map).permit(
      :enable
    )
  end


  def response_record_json
    data = common_json_data('100')
    data[:columns] = @columns
    data[:records] = []
    @records.each do |record|
      row = {}
      @columns.each do |column|
        row[column] = record[column]
      end
      data[:records] << row
    end

    render_json(data)
  end
  
end
