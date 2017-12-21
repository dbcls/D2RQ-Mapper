require 'togo_mapper/namespace'
require 'togo_mapper/d2rq'

class ClassMapsController < ApplicationController
  include TogoMapper::Namespace

  def show
    @class_map = ClassMap.find(params[:id])
    @work = @class_map.work
    validate_user(@work.id)
    
    @namespace_prefixes = namespace_prefixes_by_namespace_settings(@work.id)
    @base_uri = @work.base_uri.blank? ? DEFAULT_BASE_URI : @work.base_uri

    property_bridge_for_label = @class_map.property_bridge_for_resource_label
    
    @subject_cmps = @class_map.property_setting_for_resource_identity
    @rdf_type_cmps = @class_map.property_settings_for_class

    if params[:class]
      if @rdf_type_cmps.size == 1 && @rdf_type_cmps[0].value == default_class_map_rdf_type(@class_map)
        @rdf_type_cmps[0].value = params[:class]
      else
        @new_resource_class = params[:class]
      end
    end
    
    @resource_label_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: property_bridge_for_label.id,
      property_bridge_property_id: PropertyBridgeProperty.literal_pattern.id
    ).first

    @resource_label_lang_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: property_bridge_for_label.id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id
    ).first

    @condition_cmps = @class_map.cmps_for_condition
    if @condition_cmps.nil?
      @condition_cmps = ClassMapPropertySetting.create(
        class_map_id: @class_map.id,
        class_map_property_id: ClassMapProperty.condition.id,
        value: ""
      )      
    end
    
    if xhr?
      set_headers_for_cross_domain
      data = common_json_data('100')
      data[:subject] = {
        id: @class_map.id,
        uri: {
          id: @subject_cmps.id,
          d2rq_property: @subject_cmps.class_map_property.property,
          value: @subject_cmps.value
        },
        classes: [],
        label: {
          id: @resource_label_pbps.id,
          value: @resource_label_pbps.value
        },
        language: {
          id: @resource_label_lang_pbps.id,
          value: @resource_label_lang_pbps.value
        },
        where_condition: {
          id: @condition_cmps.id,
          value: @condition_cmps.value
        }
      }
      @rdf_type_cmps.each do |cmps|
        data[:subject][:classes] << {
          id: cmps.id,
          value: cmps.value
        }
      end
      render_json(data)
    else
      render partial: 'subject_map_dialog'
    end
  end

  
  def update
    @class_map = ClassMap.find(params[:id])
    @work = @class_map.work
    validate_user(@work.id)

    @cmps_ids = params["class_map_property_setting"].to_unsafe_h.keys
    @pbps_ids = params["property_bridge_property_setting"].to_unsafe_h.keys

    validate_result = validate_subject_map
    if validate_result.is_a?(Array)
      @errors = validate_result
      @warnings = []
    else
      @errors = validate_result[:errors]
      @warnings = validate_result[:warnings]
    end
    
    unless @errors.empty?
      @target = 'Subject Mapping'
      render 'validation_error', format: 'js'
      return
    end
    
    ActiveRecord::Base.transaction do
      delete_subject_classes(@class_map.id)
      add_subject_classes
      
      @cmps_ids.each do |cmps_id|
        update_class_map_property_setting(cmps_id)
      end

      @pbps_ids.each do |pbps_id|
        update_property_bridge_property_setting(pbps_id)
      end
    end

    success_message = "Subject mapping of table '#{@class_map.table_name}' was successfully saved."
    if @warnings.empty?
      @status = 'success'
      @message = success_message
    else
      @status = 'warning'
      @message = "<br />#{@warnings.join('<br />')}<br /><br />#{success_message}"
    end
  end
  

  def enable
    @class_map = ClassMap.find(params[:id])
    validate_user(@class_map.work.id)

    if xhr?
      set_headers_for_cross_domain
      response_json
    end
  end

  
  def toggle_enable
    class_map = ClassMap.find(params[:id])
    validate_user(class_map.work.id)
    
    class_map.enable = !class_map.enable
    class_map.save!
  end

  private

  def response_json
    data = common_json_data('100')
    data[:enable] = @class_map.enable

    render_json(data)
  end    

end
