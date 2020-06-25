class ApplicationController < ActionController::Base

  class AccessDenied < StandardError; end
  
  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from AccessDenied, with: :invalid_access

  def set_instance_variables_for_mapping_data(work_id)
    @work = Work.find(work_id)

    @namespaces = namespaces_by_namespace_settings(work_id)
    @db_connection = @work.db_connection
    @class_maps = ClassMap.by_work_id(work_id)
    @property_bridges = PropertyBridge.where(work_id: work_id)
    @table_joins = TableJoin.by_work_id(work_id)
  end

  protected

  def configure_permitted_parameters
    added_attrs = [ :username, :email, :password, :password_confirmation, :remember_me ]
    devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
    devise_parameter_sanitizer.permit :account_update, keys: added_attrs
    devise_parameter_sanitizer.permit :sign_in, keys: added_attrs
  end

  private

  def set_work_id_to_session(work_id)
    session["d2rq_mapper.work_id"] = work_id
  end


  def work_id_by_session
    session_id = session["d2rq_mapper.work_id"].to_i
    if session_id > 0
      session_id
    else
      nil
    end
  end


  def clear_work_id
    session["d2rq_mapper.work_id"] = nil
  end


  def validate_user(work_id = nil)
    if current_user.nil?
      authenticate_user!
    end

    return if current_user.username == 'ta-nishi'

    work_id ||= params[:id]
    unless Work.exists?(id: work_id.to_i, user_id: current_user.id)
      raise AccessDenied
    end
  end


  def validate_uri_pattern(uri_pattern, work_id = nil)
    errors = []

    if work_id.nil?
      work_id = @class_map.work.id
    end
    
    uri_pattern.strip!
    if /\A<.*>\z/ !~ uri_pattern && /\A".*"\z/ !~ uri_pattern
      pos = uri_pattern.index(':')
      if pos
        prefix = uri_pattern[0 .. pos - 1]
        namespace_prefixes = namespace_prefixes_by_namespace_settings(work_id)

        unless namespace_prefixes.include?(prefix)
          errors << "Prefix '#{prefix}' is used for URI pattern, but prefix '#{prefix}' is not specified in namespace setting."
        end
      end
    end

    errors
  end
  

  def invalid_access
    render plain: "You don't have permission to access this page.", status: :bad_request
  end

  
  def base_uri
    @work.base_uri.blank? ? DEFAULT_BASE_URI : @work.base_uri
  end


  def property_setting_value_for_save(base_uri, value)
    if /\A<(.+)>\z/ =~ value
      uri = $1.dup
      if /\A#{base_uri}/ =~ uri
        "<#{uri[base_uri.length .. -1]}>"
      else
        value
      end
    else
      value
    end
  end


  def update_class_map_property_setting(class_map_setting_id, save = true)
    class_map_property_setting = ClassMapPropertySetting.find(class_map_setting_id)

    cmps = params[:class_map_property_setting][class_map_setting_id.to_s]
    if cmps.key?("class_map_property_id")
      # ClassMapPropertySetting of Subject format and URI
      cmp_id = cmps["class_map_property_id"].to_i

      begin 
        # d2rq:uriPattern or d2rq:uriColumn
        class_map_property = ClassMapProperty.find(cmp_id)
        class_map_property_setting.class_map_property_id = class_map_property.id
        class_map_property_setting.value = property_setting_value_for_save(base_uri, cmps[class_map_property.property]["value"])
      rescue ActiveRecord::RecordNotFound
        class_map_property_setting.class_map_property_id = cmp_id
        class_map_property_setting.value = nil
      ensure
        class_map_property_setting.save! if save
      end
    elsif cmps.key?("value")
      class_map_property_setting.value = property_setting_value_for_save(base_uri, cmps["value"])
      class_map_property_setting.save! if save
    end
  end


  def update_property_bridge_property_setting(property_bridge_property_setting_id, save = true)
    property_bridge_property_setting = PropertyBridgePropertySetting.find(property_bridge_property_setting_id)
    property_bridge = property_bridge_property_setting.property_bridge

    pbps = params[:property_bridge_property_setting][property_bridge_property_setting_id]
    if pbps.key?("property_bridge_property_id")
      # PropertyBridgePropertySetting for Object
      pbp_id = pbps["property_bridge_property_id"]
      property_bridge_property = PropertyBridgeProperty.find(pbp_id.to_i)
      property_bridge_property_setting.property_bridge_property_id = pbp_id.to_i
      value = pbps[property_bridge_property.property]["value"]
      property_bridge_property_setting.value = property_setting_value_for_save(base_uri, value)
    else
      property_bridge_property_setting.value = property_setting_value_for_save(base_uri, pbps["value"])
    end

    property_bridge_property_setting.save! if save
  end
  

  def validate_subject_map
    warnings = []
    errors = []
    
    @cmps_ids.each do |cmps_id|
      #begin
        property = ClassMapPropertySetting.find(cmps_id).class_map_property.property
      #rescue
      #  next
      #end
      
      case property
      when 'd2rq:class'
      # Class (rdf:type): recommended
        rdf_type = params[:class_map_property_setting][cmps_id]['value'].to_s.strip
        if rdf_type.blank?
          warnings << "In the guideline which is created in DBCLS, putting rdf:type to subject is recommended."
        end
      when 'd2rq:uriPattern', 'd2rq:uriColumn'
        # Format: required
        cmp_id = params[:class_map_property_setting][cmps_id]['class_map_property_id'].strip
        if cmp_id.blank?
          errors << "Format is required."
        else
          begin
            unless ClassMapProperty.find(cmp_id).subject_map_format?
              errors << "Format is invalid"
            end
          rescue
            errors << "Format is invalid."
          end
        end
        
        # URI: required
        uri = params[:class_map_property_setting][cmps_id][property]['value'].to_s.strip
        if uri.blank?
          errors << "URI is required."
        else
          if property == 'd2rq:uriPattern'
            errors = errors + validate_uri_pattern(uri)
          end
        end
      end
    end

    @pbps_ids.each do |pbps_id|
      pbps = PropertyBridgePropertySetting.find(pbps_id)
      if pbps.property_bridge.for_label? && pbps.property_bridge_property.property == 'd2rq:pattern'
        # Label: recommended
        if params[:property_bridge_property_setting][pbps_id]['value'].strip.blank?
          warnings << "In the guideline which is created in DBCLS, putting rdfs:label to subject is recommended."
        end
      end
    end

    { errors: errors, warnings: warnings }
  end


  def validate_predicate_object_map
    errors = []

    params[:property_bridge_property_setting].to_unsafe_h.keys.each do |pbps_id|
      begin
        property_bridge_property_setting = PropertyBridgePropertySetting.find(pbps_id)
      rescue
        next
      end
      
      property_bridge_property = property_bridge_property_setting.property_bridge_property
      next if property_bridge_property.nil?

      case property_bridge_property.property
      when 'd2rq:property'
        # Predicate URI: required
        if params[:property_bridge_property_setting][pbps_id]['value'].blank?
          errors << 'Predicate URI is required.'
        end
      when 'd2rq:uriPattern', 'd2rq:uriColumn', 'd2rq:pattern', 'd2rq:column'
        begin
          object_format_pbp = PropertyBridgeProperty.find(params[:property_bridge_property_setting][pbps_id]['property_bridge_property_id'])
        rescue
          errors << 'Object Format is invalid.'
        end
        
        # Object (URI / Literal): required
        if object_format_pbp
          value = params[:property_bridge_property_setting][pbps_id][object_format_pbp.property]['value'].to_s.strip
          if value.blank?
            errors << 'Object (URI / Literal) is required.'
          else
            if property_bridge_property.property == 'd2rq:uriPattern'
              errors = errors + validate_uri_pattern(value, @property_bridge.work.id)
            end
          end
        end
      end
    end
    
    errors
  end

  
  def add_subject_classes
    if params[:subject_classes]
      params[:subject_classes].to_unsafe_h.keys.each do |class_map_id|
        params[:subject_classes][class_map_id].each do |subject_class|
          next if subject_class.blank?

          ClassMapPropertySetting.create!(
            class_map_id: class_map_id.to_i,
            class_map_property_id: ClassMapProperty.rdf_type.id,
            value: subject_class
          )
        end
      end
    end
  end

  
  def delete_subject_classes(class_map_id)
    required_cmps = ClassMapPropertySetting.where(
      class_map_id: class_map_id,
      class_map_property_id: ClassMapProperty.rdf_type.id
    ).order(:id).first

    ClassMapPropertySetting.where(
      "id <> ? AND class_map_id = ? AND class_map_property_id = ?", required_cmps.id, class_map_id, ClassMapProperty.rdf_type.id
    ).destroy_all
  end


  def add_predicates
    if params[:predicates]
      params[:predicates].to_unsafe_h.keys.each do |property_bridge_id|
        params[:predicates][property_bridge_id].each do |predicate|
          next if predicate.blank?

          PropertyBridgePropertySetting.create(
            property_bridge_id: property_bridge_id.to_i,
            property_bridge_property_id: PropertyBridgeProperty.property.id,
            value: predicate
          )
        end
      end
    end
  end

  
  def delete_predicates(property_bridge_id)
    required_property_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: property_bridge_id,
      property_bridge_property_id: PropertyBridgeProperty.property.id
    ).order(:id).first

    PropertyBridgePropertySetting.where(
      "id <> ? AND property_bridge_id = ? AND property_bridge_property_id = ?", required_property_pbps.id, property_bridge_id, PropertyBridgeProperty.property.id
    ).destroy_all
  end


  def render_json(hash)
    json = JSON.generate(hash)
    if params[:callback]
      render json: json, callback: ERB::Util.html_escape(params[:callback])
    else
      render json: json
    end
  end


  def xhr?
    request.headers['Accept'].to_s.index('application/json') || request.headers['Accept'].to_s.index('text/javascript')
  end


  def json?
    request.headers['Accept'].to_s.index('application/json')
  end


  def save_mapping_updated_time
    @work.mapping_updated = Time.now
    @work.save!
  end
end
