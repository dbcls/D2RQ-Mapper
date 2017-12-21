require 'togo_mapper/namespace'

class PropertyBridgesController < ApplicationController
  include TogoMapper::Namespace

  def index
    @property_bridge = PropertyBridge.find(params[:id])
    @work = @property_bridge.work
    validate_user(@work.id)

    set_instance_variables
  end

  
  def show
    @property_bridge = PropertyBridge.find(params[:id])
    @work = @property_bridge.work
    validate_user(@work.id)

    set_instance_variables

    if xhr?
      set_headers_for_cross_domain
      response_json
    else
    end
  end

  
  def create
    class_map = ClassMap.find(params[:triples_map_id])
    src_pb = PropertyBridge.find(params[:src_pbid])

    ActiveRecord::Base.transaction do
      property_bridge = PropertyBridge.create!(
        work_id: class_map.work_id,
        class_map_id: class_map.id,
        column_name: src_pb.column_name,
        enable: true,
        user_defined: true,
        property_bridge_type_id: src_pb.property_bridge_type_id
      )

      params["property_bridge_property_setting"].to_unsafe_h.keys.each do |pbps_id|
        src_pbps = PropertyBridgePropertySetting.find(pbps_id)
        if params["property_bridge_property_setting"][pbps_id].key?('property_bridge_property_id')
          pbp = PropertyBridgeProperty.find(params["property_bridge_property_setting"][pbps_id]['property_bridge_property_id'])
          PropertyBridgePropertySetting.create!(
            property_bridge_id: property_bridge.id,
            property_bridge_property_id: pbp.id,
            value: params["property_bridge_property_setting"][pbps_id][pbp.property]['value']
          )
        elsif params["property_bridge_property_setting"][pbps_id].key?('value')
          PropertyBridgePropertySetting.create!(
            property_bridge_id: property_bridge.id,
            property_bridge_property_id: src_pbps.property_bridge_property_id,
            value: params["property_bridge_property_setting"][pbps_id]['value']
          )
        end
      end
    end
    
    redirect_to er_url(class_map.work_id)
  end

  
  def update
    @property_bridge = PropertyBridge.find(params[:id])
    validate_user(@property_bridge.work.id)
    
    @errors = validate_predicate_object_map
    unless @errors.empty?
      @target = 'Predicate-Object Mapping'
      render 'predicate_object_map_validation_error', format: 'js'
      return
    end
    
    ActiveRecord::Base.transaction do
      @work = Work.find(@property_bridge.work_id)

      delete_predicates(@property_bridge.id)
      add_predicates

      params["property_bridge_property_setting"].to_unsafe_h.keys.each do |pbps_id|
        update_property_bridge_property_setting(pbps_id)
      end
    end
    @status = 'success'
    @message = "Predicate-Object mapping of column '#{@property_bridge.column_name}' was successfully saved."
  end


  def enable
    @property_bridge = PropertyBridge.find(params[:id])
    validate_user(@property_bridge.work.id)

    if xhr?
      set_headers_for_cross_domain
      response_json_for_enable
    end
  end

  
  def toggle_enable
    property_bridge = PropertyBridge.find(params[:id])
    validate_user(property_bridge.work.id)
    
    property_bridge.enable = !property_bridge.enable
    property_bridge.save!
  end

  private

  def set_instance_variables
    @predicate_pbps = @property_bridge.predicate
    @object_pbps = @property_bridge.object.first
    @lang_pbps = @property_bridge.pbps_for_lang
    @datatype_pbps = @property_bridge.pbps_for_datatype
    @condition_pbps = @property_bridge.pbps_for_condition
    if @condition_pbps.nil?
      @condition_pbps = PropertyBridgePropertySetting.create(
        property_bridge_id: @property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.condition.id,
        value: ""
      )
    end
    
    if params[:property]
      @property_type = find_property_type(params[:property])
      if @predicate_pbps.size == 1 && @predicate_pbps[0].value == default_predicate_uri(@predicate_pbps[0].property_bridge.class_map.table_name, @predicate_pbps[0].property_bridge.column_name)
        @predicate_pbps[0].value = params[:property]
        if @property_type == 'datatype-property'
          @object_pbps.property_bridge_property_id = PropertyBridgeProperty.where(property: 'd2rq:column').first.id
        else
          @object_pbps.property_bridge_property_id = PropertyBridgeProperty.where(property: 'd2rq:uriColumn').first.id
        end
      else
        @new_property = params[:property]
      end
    end

    @class_map = ClassMap.find(@property_bridge.class_map_id)
    @column_property_bridges = @class_map.column_property_bridges
    @namespace_prefixes = namespace_prefixes_by_namespace_settings(@work.id)
    @base_uri = @work.base_uri.blank? ? DEFAULT_BASE_URI : @work.base_uri
  end


  def response_json
    data = common_json_data('100')
    data[:predicate_object] = {
      predicates: [],
      object: {
        id: @object_pbps.id,
        d2rq_property_id: @object_pbps.property_bridge_property.id,
        d2rq_property: @object_pbps.property_bridge_property.property,
        value: @object_pbps.value
      },
      language: {
        id: @lang_pbps.id,
        value: @lang_pbps.value
      },
      datatype: {
        id: @datatype_pbps.id,
        value: @datatype_pbps.value
      },
      where_condition: {
        id: @condition_pbps.id,
        value: @condition_pbps.value
      }
    }

    @predicate_pbps.each do |pbps|
      data[:predicate_object][:predicates] << {
        id: pbps.id,
        d2rq_property: pbps.property_bridge_property.property,
        value: pbps.value
      }
    end
    
    render_json(data)
  end

  
  def response_json_for_enable
    data = common_json_data('100')
    data[:enable] = @property_bridge.enable

    render_json(data)
  end
  
end
