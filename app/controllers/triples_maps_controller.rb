require 'togo_mapper/mapping'
require 'togo_mapper/namespace'
require 'togo_mapper/d2rq'

class TriplesMapsController < ApplicationController
  include TogoMapper::Mapping
  include TogoMapper::Namespace
  include TogoMapper::D2RQ

  protect_from_forgery except: [:update]
  before_action :authenticate_user!, :set_html_body_class
  before_action :set_class_map, only: [ :show, :update, :new_constant_predicate_object_form, :new_property_bridge_form ]
  before_action :set_property_bridge, only: [ :new_property_bridge_form, :del_property_bridge_form ]

  def index
  end


  def create
  end


  def new
  end


  def edit
  end


  def show
    @table_not_found = false

    validate_user(@class_map.work_id)

    # Check if I connect to the database
    begin
      db_conn = DbConnection.where(work_id: @class_map.work_id).first
      TogoMapper::DB.new(db_conn.connection_config)
    rescue => e
      flash[:error] = e.message.force_encoding("UTF-8")
      redirect_to menu_path(@class_map.work_id)
      return
    end
    
    begin
      @work = @class_map.work

      # Synchronize database schema and mapping settings
      maintain_consistency_with_rdb

      if !@class_map.table_name.blank? && !@work.table_exists?(@class_map.table_name)
        @table_not_found = true
        @grouped_triples_maps = options_for_table_selector(@class_map)
      else
        set_instance_variables(@class_map)
        set_models_by_rdb
      end
    rescue => e
      logger.fatal e.inspect
      logger.fatal e.backtrace.join("\n")
      flash.now[:err] = "Sorry, system error has occurred."
      render action: 'show'
    end
  end


  def update
    validate_user(@class_map.work_id)

    errors = validate_posted_values
    unless errors.empty?
      errmsg = "Mapping was not saved because of the following error"
      if errors.size > 1
        errmsg << "s"
      end
      set_instance_variables(@class_map)
      set_models_by_update_params(false)
      flash.now[:err] = "#{errmsg}.<br />#{errors.join('<br />')}"
      render action: 'show'
      return
    end

    begin
      ActiveRecord::Base.transaction do
        set_instance_variables(@class_map)
        set_models_by_update_params(true)
        save_mapping_updated_time
      end
      if request.xhr?
        if params.key?("class_map_property_setting")
          render js: "$('#subject-mapping-message').html('Mapping was successfully saved.');"
        else
          render js: "$('#predicate-object-mapping-message').html('Mapping was successfully saved.');"
        end
      else
        flash[:msg] = "Mapping was successfully saved."
        redirect_to triples_map_url(@class_map)
      end
    rescue => e
      logger.fatal e.inspect
      logger.fatal e.backtrace.join("\n")
      flash.now[:err] = "Sorry, system error has occurred."
      render action: 'show'
    end
  end


  def destroy
  end


  def new_property_bridge_form
    validate_user(@class_map.work.id)

    property_bridge = create_property_bridge
    pbps_hash = new_pbps_hash(property_bridge.id)
    set_instance_variables(@class_map)
    set_models_by_rdb

    render partial: 'property_bridge_form_for_add',
           locals: { property_bridge: property_bridge,
                     property_bridge_property_setting: pbps_hash }
  end


  def new_constant_predicate_object_form
    validate_user(@class_map.work.id)

    property_bridge = create_property_bridge_for_constant
    pbps_hash = new_pbps_hash(property_bridge.id)
    set_instance_variables(@class_map)
    set_models_by_rdb

    render partial: 'property_bridge_form_for_add',
           locals: { property_bridge: property_bridge,
                     property_bridge_property_setting: pbps_hash }
  end


  def del_property_bridge_form
    validate_user(@property_bridge.work.id)
    
    ActiveRecord::Base.transaction do
      PropertyBridgePropertySetting.destroy_all(property_bridge_id: @property_bridge.id)

      ColumnPropertyBridge.where(property_bridge_id: @property_bridge.id).each do |cpb|
        cpb.destroy!
      end

      PropertyBridge.destroy(@property_bridge.id)
    end

    head :ok
  end


  def new_predicate_form
    render partial: 'predicate_form_for_add', locals: {property_bridge_id: params[:property_bridge_id]}
  end

  private

  def set_class_map
    @class_map = ClassMap.find(params[:id])
  end

  def set_property_bridge
    @property_bridge = PropertyBridge.find(params[:property_bridge_id])
  end

  def set_instance_variables(class_map)
    @work = Work.find(class_map.work_id)
    @db_connection = DbConnection.where(work_id: @work.id).first

    @table_join = class_map.table_join
    if @table_join
      @class_map_type = 'J'
    else
      @class_map_type = 'T'
    end

    @base_uri = @work.base_uri.blank? ? DEFAULT_BASE_URI : @work.base_uri
    @class_maps = ClassMap.by_work_id(@work.id)
    @property_bridge_hash = {}
    class_map.column_property_bridges.each do |property_bridge|
      @property_bridge_hash[property_bridge.real_column_name] = property_bridge
    end

    @subject_format_properties = ClassMapProperty.for_resource_identity
    @subject_format_properties << ClassMapProperty.bnode

    # for "Selected table" <select>...</select>
    @grouped_triples_maps = options_for_table_selector(class_map)
    
    @selected_key = params[:id]

    @object_properties = object_property_bridge_properties
    case @class_map_type
    when 'T'
      @property_bridges_for_subject_column_selector = PropertyBridge.where(
        class_map_id: class_map.id,
        property_bridge_type_id: PropertyBridgeType.column.id
      ).order(:id)

      @property_bridges_for_object_column_selector = @property_bridges_for_subject_column_selector
    when 'J'
      @property_bridges_for_subject_column_selector = PropertyBridge.where(
        class_map_id: class_map.table_join.l_table.id,
        property_bridge_type_id: PropertyBridgeType.column.id
      ).order(:id)

      @property_bridges_for_object_column_selector = PropertyBridge.where(
        class_map_id: class_map.table_join.r_table.id,
        property_bridge_type_id: PropertyBridgeType.column.id
      ).order(:id)
    end

    @namespace_prefixes = namespace_prefixes_by_namespace_settings(@work.id)

    # Example records
    unless @table_not_found
      fetch_example_records(class_map)
    end
  end


  def options_for_table_selector(class_map)
    options = []
    
    opts = ClassMap.table_derived(class_map.work_id).select(&:enable).map{ |class_map| [ class_map.table_name, class_map.id ] }
    unless opts.empty?
      options << ['Table'] + [opts] 
    end

    if TableJoin.exists?(work_id: class_map.work_id)
      opts = TableJoin.by_work_id(class_map.work_id).select{ |table_join| table_join.class_map.enable }.map{ |table_join| [ table_join.label, table_join.class_map.id ] }
      unless opts.empty?
        options << ['Join'] + [opts]
      end
    end

    if BlankNode.exists?(work_id: class_map.work_id)
      opts = ClassMap.where('work_id =? AND bnode_id > 0', class_map.work_id).select(&:enable).map{ |class_map| [ "Blank node: #{class_map.bnode_id_columns}", class_map.id ] }
      unless opts.empty?
        options << ['Blank node'] + [opts]
      end
    end

    options
  end
  

  def set_models_by_rdb
    @class_map_property_setting = {}
    @class_map_property_setting[:rdf_type] = []

    @subject_uri = {}
    ClassMapProperty.for_resource_identity.each do |cmp|
      columns = PropertyBridge.where(class_map_id: @class_map.id).order(:id).map(&:column_name)
      if cmp.property == 'd2rq:uriPattern'
        @subject_uri[cmp.property] = default_subject_uri(@class_map.table_name, columns[0])
      else
        @subject_uri[cmp.property] = ""
      end
    end

    ClassMapPropertySetting.where(class_map_id: @class_map.id).each do |cmps|
      if cmps.subject?
        @class_map_property_setting[:subject] = cmps
        unless cmps.class_map_property_id == 0
          @subject_uri[cmps.class_map_property.property] = cmps.value
        end
      elsif cmps.rdf_type?
        @class_map_property_setting[:rdf_type] << cmps
      elsif cmps.condition?
        @class_map_property_setting[:condition] = cmps
      end
    end

    if @class_map_property_setting[:rdf_type].empty?
      @class_map_property_setting[:rdf_type] << ClassMapPropertySetting.create(
        class_map_id: @class_map.id,
        class_map_property_id: ClassMapProperty.rdf_type.id,
        value: default_class_map_rdf_type(@class_map)
      )
    end

    unless @class_map_property_setting.key?(:condition)
      @class_map_property_setting[:condition] = ClassMapPropertySetting.create(
        class_map_id: @class_map.id,
        class_map_property_id: ClassMapProperty.condition.id,
        value: ""
      )
    end

    # Resource label
    @resource_label_property_bridge = @class_map.property_bridge_for_resource_label
    if @resource_label_property_bridge
      @resource_label = property_bridge_property_setting_for_resource_label(@resource_label_property_bridge.id)
    else
      @resource_label = create_models_for_resource_label(@class_map)
      @resource_label_property_bridge = @resource_label[:property_bridge]
    end

    # Predicate & Object (PropertyBridge, PropertyBridgePropertySetting)
    ignored_ids = []
    @property_bridges = []

    PropertyBridge.where(
      work_id: @work.id,
      class_map_id: @class_map.id,
      property_bridge_type_id: PropertyBridgeType.column.id
    ).order(:id).each do |pb|
      PropertyBridge.where(
        work_id: @work.id,
        class_map_id: @class_map.id,
        column_name: pb.column_name,
        property_bridge_type_id: PropertyBridgeType.column.id
      ).order(:id).each do |property_bridge|
        unless ignored_ids.include?(property_bridge.id)
          @property_bridges << property_bridge
          ignored_ids << property_bridge.id
        end
      end
    end
    PropertyBridge.where(work_id: @work.id,
                         class_map_id: @class_map.id,
                         property_bridge_type_id: PropertyBridgeType.constant.id).order(:id).each do |property_bridge|
      @property_bridges << property_bridge
      ignored_ids << property_bridge.id
    end

    @object_value = {}
    @property_bridge_property_setting = {}
    @property_bridges.each do |property_bridge|
      # Predicate
      property_bridge_properties = PropertyBridgeProperty.predicate_properties
      predicates = PropertyBridgePropertySetting.where(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: property_bridge_properties.map(&:id)
      )

      # Object
      @object_value[property_bridge.id] = {}
      @object_properties.each do |pbp|
        @object_value[property_bridge.id][pbp.property] = default_object_value(property_bridge, pbp.property)
      end

      object = PropertyBridgePropertySetting.where(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: @object_properties.map(&:id)
      ).first
      @object_value[property_bridge.id][object.property_bridge_property.property] = object.value

      # Language
      property_bridge_property = PropertyBridgeProperty.lang
      language = PropertyBridgePropertySetting.where(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: property_bridge_property.id
      ).first

      # Datatype
      property_bridge_property = PropertyBridgeProperty.datatype
      datatype = PropertyBridgePropertySetting.where(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: property_bridge_property.id
      ).first

      # SQL where condition
      property_bridge_property = PropertyBridgeProperty.condition
      condition = PropertyBridgePropertySetting.where(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: property_bridge_property.id
      ).first
      if condition.nil?
        condition = PropertyBridgePropertySetting.create(
          property_bridge_id: property_bridge.id,
          property_bridge_property_id: property_bridge_property.id,
          value: ""
        )
      end

      # PropertyBridgePropertySetting
      @property_bridge_property_setting[property_bridge.id] = {
        predicates: predicates,
        object: object,
        language: language,
        datatype: datatype,
        condition: condition
      }

      @blank_node = {}
      BlankNode.where(class_map_id: @class_map.id).each do |blank_node|
        unless @blank_node.key?(blank_node.id)
          @blank_node[blank_node.id] = { blank_node: blank_node }
        end
        property_bridge = PropertyBridge.where(bnode_id: blank_node.id).first
        @blank_node[blank_node.id][:predicates] = PropertyBridgePropertySetting.where(
          property_bridge_id: property_bridge.id,
          property_bridge_property_id: PropertyBridgeProperty.property.id)
        @blank_node[blank_node.id][:condition] = PropertyBridgePropertySetting.where(
          property_bridge_id: property_bridge.id,
          property_bridge_property_id: PropertyBridgeProperty.condition.id).first
        if @blank_node[blank_node.id][:condition].nil?
          @blank_node[blank_node.id][:condition] = PropertyBridgePropertySetting.create(
            property_bridge_id: property_bridge.id,
            property_bridge_property_id: PropertyBridgeProperty.condition.id,
            value: ''
          )
        end
      end
    end
  end


  def set_models_by_update_params(save = false)
    @subject_uri = {}
    ClassMapProperty.for_resource_identity.each do |cmp|
      @subject_uri[cmp.property] = ""
    end

    @class_map_property_setting = {}
    @class_map_property_setting[:rdf_type] = []

    if params["class_map_property_setting"]
      class_map_property_sertting_ids = params["class_map_property_setting"].to_unsafe_h.keys
      class_map_property_sertting_ids.each do |cmps_id|
        cmps = params["class_map_property_setting"][cmps_id]
        cmap_prop_setting = ClassMapPropertySetting.find(cmps_id)

        if cmps.key?("class_map_property_id")
          cmp_id = cmps["class_map_property_id"].to_i

          begin 
            class_map_property = ClassMapProperty.find(cmp_id)
            cmap_prop_setting.class_map_property_id = class_map_property.id
            cmap_prop_setting.value = property_setting_value_for_save(@base_uri, cmps[class_map_property.property]["value"])
          rescue ActiveRecord::RecordNotFound
            cmap_prop_setting.class_map_property_id = cmp_id
            cmap_prop_setting.value = nil
          ensure
            cmap_prop_setting.save! if save

            if cmap_prop_setting.subject?
              @subject_uri[cmap_prop_setting.class_map_property.property] = cmap_prop_setting.value
            end
            @class_map_property_setting[:subject] = cmap_prop_setting
          end
        elsif cmps.key?("value")
          cmap_prop_setting = ClassMapPropertySetting.find(cmps_id)
          cmap_prop_setting.value = property_setting_value_for_save(@base_uri, cmps["value"])
          cmap_prop_setting.save! if save
          
          if cmap_prop_setting.rdf_type?
            @class_map_property_setting[:rdf_type] << cmap_prop_setting
          end

          if cmap_prop_setting.condition?
            @class_map_property_setting[:condition] = cmap_prop_setting
          end
        end
      end

      # Delete rdf:type
      ClassMapPropertySetting.where(class_map_id: @class_map.id, class_map_property_id: ClassMapProperty.rdf_type.id).each do |cmps|
        unless class_map_property_sertting_ids.include?(cmps.id.to_s)
          cmps.destroy
        end
      end

      # New rdf:type
      if params[:subject_rdf_types]
        params[:subject_rdf_types].each do |subject_rdf_type|
          next if subject_rdf_type.blank?
          
          ClassMapPropertySetting.create(
            class_map_id: @class_map.id,
            class_map_property_id: ClassMapProperty.rdf_type.id,
            value: subject_rdf_type
          )
        end
      end
    end


    # PropertyBridge
    @property_bridges = []
    if params["property_bridge"]
      params["property_bridge"].to_unsafe_h.keys.each do |pb_id|
        property_bridge = PropertyBridge.find(pb_id)
        property_bridge.enable = params["property_bridge"][pb_id]["enable"]
        if save
          property_bridge.save! if save
        else
          @property_bridges << property_bridge
        end
      end
    end

    # Predicate
    predicate_pbp_ids = PropertyBridgeProperty.predicate_properties.map(&:id)

    # Object
    @object_value = {}

    # Language, Datatype, Condition
    language_pbp_id = PropertyBridgeProperty.lang.id
    datatype_pbp_id = PropertyBridgeProperty.datatype.id
    condition_pbp_id = PropertyBridgeProperty.condition.id

    # PropertyBridge for Subject(resource) label
    @resource_label = {
      predicate: nil,
      object: nil,
      lang: nil
    }

    # Blank node
    @blank_node = {}

    @property_bridge_property_setting = {}
    pbps_ids = params["property_bridge_property_setting"].to_unsafe_h.keys
    pbps_ids.each do |pbps_id|
      property_bridge_property_setting = PropertyBridgePropertySetting.find(pbps_id)
      property_bridge = property_bridge_property_setting.property_bridge
      unless @object_value.key?(property_bridge.id)
        @object_value[property_bridge.id] = {}
        @object_properties.map(&:property).each do |property|
          @object_value[property_bridge.id][property] = ""
        end
      end

      pbps = params["property_bridge_property_setting"][pbps_id]
      if pbps.key?("property_bridge_property_id")
        pbp_id = pbps["property_bridge_property_id"]
        property_bridge_property = PropertyBridgeProperty.find(pbp_id.to_i)
        property_bridge_property_setting.property_bridge_property_id = pbp_id.to_i
        value = pbps[property_bridge_property.property]["value"]
        property_bridge_property_setting.value = property_setting_value_for_save(@base_uri, value)
        if @object_properties.map(&:property).include?(property_bridge_property.property)
          @object_value[property_bridge.id][property_bridge_property.property] = value
        end
      else
        property_bridge_property_setting.value = property_setting_value_for_save(@base_uri, pbps["value"])
      end

      if save
        property_bridge_property_setting.save!
      else
        if property_bridge.for_label?
          # Resource label
          @resource_label_property_bridge = property_bridge

          case property_bridge_property_setting.property_bridge_property_id
          when PropertyBridgeProperty.property.id
            @resource_label[:predicate] = property_bridge_property_setting
          when PropertyBridgeProperty.literal_pattern.id
            @resource_label[:object] = property_bridge_property_setting
          when PropertyBridgeProperty.lang.id
            @resource_label[:lang] = property_bridge_property_setting
          end
        elsif property_bridge.for_bnode?
          unless @blank_node.key?(property_bridge.bnode_id)
            @blank_node[property_bridge.bnode_id] = {
              predicates: [],
              condition: "",
              blank_node: BlankNode.find(property_bridge.bnode_id)
            }
          end
          case property_bridge_property_setting.property_bridge_property_id
          when PropertyBridgeProperty.property.id
            @blank_node[property_bridge.bnode_id][:predicates] << property_bridge_property_setting
          when PropertyBridgeProperty.condition.id
            @blank_node[property_bridge.bnode_id][:condition] = property_bridge_property_setting
          end
        else
          # Predicate-Object map
          unless @property_bridge_property_setting.key?(property_bridge.id)
            @property_bridge_property_setting[property_bridge.id] = {}
            @property_bridge_property_setting[property_bridge.id][:predicates] = []
          end

          if predicate_pbp_ids.include?(property_bridge_property_setting.property_bridge_property_id)
            @property_bridge_property_setting[property_bridge.id][:predicates] << property_bridge_property_setting
          elsif @object_properties.map(&:id).include?(property_bridge_property_setting.property_bridge_property_id)
            @property_bridge_property_setting[property_bridge.id][:object] = property_bridge_property_setting
          elsif language_pbp_id == property_bridge_property_setting.property_bridge_property_id
            @property_bridge_property_setting[property_bridge.id][:language] = property_bridge_property_setting
          elsif datatype_pbp_id == property_bridge_property_setting.property_bridge_property_id
            @property_bridge_property_setting[property_bridge.id][:datatype] = property_bridge_property_setting
          elsif condition_pbp_id == property_bridge_property_setting.property_bridge_property_id
            @property_bridge_property_setting[property_bridge.id][:condition] = property_bridge_property_setting
          end
        end
      end
    end

    # Delete predicate
    if @class_map.for_join?
      property_bridges = []
    else
      property_bridges =
          @class_map.property_bridges_for_column +
              @class_map.property_bridges_for_bnode +
                @class_map.property_bridges_for_constant

    end
    property_bridges.each do |property_bridge|
      PropertyBridgePropertySetting.where(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.property.id
      ).each do |pbps|
        unless pbps_ids.include?(pbps.id.to_s)
          pbps.destroy
        end
      end
    end

    # New predicate
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


  def property_bridge_property_setting_for_resource_label(resorce_label_prop_bridge_id)
    pbps = {}

    pbps[:predicate] = PropertyBridgePropertySetting.where(
      property_bridge_id: resorce_label_prop_bridge_id,
      property_bridge_property_id: PropertyBridgeProperty.property.id
    ).first

    pbps[:object] = PropertyBridgePropertySetting.where(
      property_bridge_id: resorce_label_prop_bridge_id,
      property_bridge_property_id: PropertyBridgeProperty.literal_pattern.id
    ).first

    pbps[:lang] = PropertyBridgePropertySetting.where(
      property_bridge_id: resorce_label_prop_bridge_id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id
    ).first

    pbps
  end


  def validate_posted_values
    errors = []

    # Subject (ClassMap)
    if params["class_map_property_setting"]
      params["class_map_property_setting"].to_unsafe_h.keys.each do |cmps_id|
        cmps = params["class_map_property_setting"][cmps_id]
        if cmps.key?("class_map_property_id")
          class_map_property_id = cmps["class_map_property_id"].to_i
          unless class_map_property_id == 0
            class_map_property = ClassMapProperty.find(class_map_property_id)
            subject_value = cmps[class_map_property.property]["value"]
            if subject_value.blank?
              errors << "Subject: URI is required."
            end
          end
        elsif cmps.key?("value")
          cmap_prop_setting = ClassMapPropertySetting.find(cmps_id.to_i)
          if cmap_prop_setting.rdf_type? && !cmap_prop_setting.class_map.for_bnode? && cmps["value"].blank?
            errors << "Subject: rdf:type is required."
          end
        end

        if class_map_property && class_map_property.property == 'd2rq:uriPattern'
          errors = errors + validate_uri_pattern(cmps[class_map_property.property]["value"])
        end
      end
    end

    # PropertyBridge
    predicate_pbp_ids = PropertyBridgeProperty.predicate_properties.map(&:id)
    object_pbp_ids = PropertyBridgeProperty.object_properties.map(&:id)
    if params["property_bridge_property_setting"]
      params["property_bridge_property_setting"].to_unsafe_h.keys.each do |id|
        format_pbp_id = nil
        property_bridge_property_setting = PropertyBridgePropertySetting.find(id)
        property_bridge = property_bridge_property_setting.property_bridge

        if property_bridge.for_label?
          if property_bridge_property_setting.property_bridge_property_id == PropertyBridgeProperty.literal_pattern.id
            if params["property_bridge_property_setting"][id]["value"].blank?
              errors << "Subject: rdfs:label is required."
            end
          end
        elsif property_bridge.for_column?
          if params["property_bridge"]
            next if params["property_bridge"][property_bridge.id.to_s] && params["property_bridge"][property_bridge.id.to_s]["enable"] == "false"
          end

          pbps = params["property_bridge_property_setting"][id]
          if pbps.key?("property_bridge_property_id")
            format_pbp_id = property_bridge_property_id = pbps["property_bridge_property_id"].to_i
          else
            property_bridge_property_id = property_bridge_property_setting.property_bridge_property.id
          end

          if predicate_pbp_ids.include?(property_bridge_property_id)
            if pbps["value"].blank?
              error_msg = "Predicate is required."
              if property_bridge.class_map.table_derived?
                error_msg = %Q(Column "#{property_bridge.real_column_name}": #{error_msg})
              end
              errors << error_msg
            end
          elsif object_pbp_ids.include?(property_bridge_property_id)
            property_bridge_property = PropertyBridgeProperty.find(property_bridge_property_id)
            if pbps[property_bridge_property.property]["value"].blank?
              error_msg = "Object (URI / Literal) is required."
              if property_bridge.class_map.table_derived?
                error_msg = %Q(Column "#{property_bridge.real_column_name}": #{error_msg})
              end
              errors << error_msg
            end
          end
        end

        if format_pbp_id && format_pbp_id == PropertyBridgeProperty.uri_pattern.id
          errors = errors + validate_uri_pattern(pbps[PropertyBridgeProperty.uri_pattern.property]["value"])
        end
      end
    end

    errors
  end


  def default_object_value(property_bridge, property)
    class_map = property_bridge.class_map
    table_join = class_map.table_join
    if table_join
      table_name = table_join.r_table.table_name
      value = "#{table_name}.#{table_join.r_column.real_column_name}"
    else
      table_name = class_map.table_name
      value = "#{table_name}.#{property_bridge.real_column_name}"
    end

    case property
    when 'd2rq:uriPattern'
      value = "#{table_name}/@@#{value}@@"
    when 'd2rq:pattern'
      value = "@@#{value}@@"
    end

    value
  end


  def object_property_bridge_properties
    if @property_bridge.present? && @property_bridge.only_pattern?
      PropertyBridgeProperty.object_pattern_properties
    else
      PropertyBridgeProperty.object_properties
    end
  end


  def fetch_example_records(class_map)
    case @class_map_type
    when 'T'
      table = class_map.table_name
      @exmaple_records_table_name = table
    when 'J'
      table_join = class_map.table_join
      @exmaple_records_table_name = table_join.label
      table = {
        main: {
          table_name: table_join.l_table.table_name,
          key_name: table_join.l_column.real_column_name,
          column_names: table_join.l_table.column_property_bridges.map(&:column_name)
        },
        join: {
          table_name: table_join.r_table.table_name,
          key_name: table_join.r_column.real_column_name,
          column_names: table_join.r_table.column_property_bridges.map(&:column_name)
        }
      }
      if table_join.multiple_join?
        table[:inter] = {
          table_name: table_join.i_table.table_name,
          l_key_name: table_join.i_l_column.real_column_name,
          r_key_name: table_join.i_r_column.real_column_name
        }
      end
    end

    db_client = TogoMapper::DB.new(@db_connection.connection_config)
    @records = db_client.records(table, 0, EXAMPLE_RECORDS_MAX_ROWS)
    deleted_keys = []
    @records.each_with_index do |record, i|
      record.each do |k, v|
        if k[0 .. 3] == 'col_'
          deleted_keys << k
        end
      end
      deleted_keys.each do |key|
        @records[i][key[4 .. -1]] = @records[i][key]
        @records[i].delete(key)
      end
      deleted_keys = []
    end
    db_client.close
  end


  def create_property_bridge
    property_bridge = PropertyBridge.create!(
        work_id: @property_bridge.work_id,
        class_map_id: @class_map.id,
        column_name: @property_bridge.column_name,
        enable: true,
        property_bridge_type_id: @property_bridge.property_bridge_type_id
    )

    ColumnPropertyBridge.create!(
        column_id: @property_bridge.id,
        property_bridge_id: property_bridge.id
    )

    # PropertyBridgePropertySetting for d2rq:belongsToClassMap
    PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.by_property('belongsToClassMap').id,
        value: @class_map.map_name
    )

    property_bridge
  end


  def new_pbps_hash(property_bridge_id)
    property_bridge = PropertyBridge.find(property_bridge_id)

    predicate = PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge_id,
        property_bridge_property_id: PropertyBridgeProperty.by_property('property').id
    )

    if property_bridge.only_pattern?
      property_bridge_property_id = PropertyBridgeProperty.literal_pattern.id
    else
      property_bridge_property_id = PropertyBridgeProperty.literal_column.id
    end
    object = PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge_id,
        property_bridge_property_id: property_bridge_property_id,
        value: ''
    )

    language = PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge_id,
        property_bridge_property_id:PropertyBridgeProperty.lang.id,
        value: ''
    )

    datatype = PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge_id,
        property_bridge_property_id: PropertyBridgeProperty.datatype.id,
        value: ''
    )

    condition = PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge_id,
        property_bridge_property_id: PropertyBridgeProperty.condition.id,
        value: ''
    )

    {
        predicates: [ predicate ],
        object: object,
        language: language,
        datatype: datatype,
        condition: condition
    }
  end


  def create_property_bridge_for_constant
    property_bridge = PropertyBridge.create!(
        work_id: @class_map.work.id,
        class_map_id: @class_map.id,
        property_bridge_type_id: PropertyBridgeType.constant.id,
        user_defined: false,
        enable: true
    )
    property_bridge.column_name = "column#{property_bridge.id}"
    property_bridge.map_name = property_bridge.generate_map_name
    property_bridge.save!

    # PropertyBridgePropertySetting for d2rq:belongsToClassMap
    PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.by_property('belongsToClassMap').id,
        value: @class_map.map_name
    )

    property_bridge
  end

  
  def set_html_body_class
    @html_body_class = 'page-configure'
  end

end
