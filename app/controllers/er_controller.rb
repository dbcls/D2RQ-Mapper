require 'togo_mapper/mapping'
require 'togo_mapper/namespace'
require 'togo_mapper/d2rq'

class ErController < ApplicationController
  include TogoMapper::Mapping
  include TogoMapper::Namespace
  include TogoMapper::D2RQ

  before_action :authenticate_user!
  before_action :validate_user, except: ['subject_map_dialog', 'predicate_object_map_dialog', 'table_join_dialog']
  
  def show
    @work = Work.find(params[:id])

    begin
      db_conn = DbConnection.where(work_id: @work.id).first
      db = TogoMapper::DB.new(db_conn.connection_config)
    rescue => e
      flash[:error] = e.message.force_encoding("UTF-8")
      redirect_to :menu
      return
    end

    maintain_consistency_with_rdb
    
    db_conn = DbConnection.where(work_id: @work.id).first
    
    set_instance_variables_for_table_and_column(db_conn)

    @table_join = TableJoin.new
    @table_join.work_id = @work.id
    @table_join.l_table_class_map_id = @class_maps[0].id
    @table_join.l_table_property_bridge_id = @property_bridges[@class_maps[0].id][0].id
    @table_join.i_table_class_map_id = nil
    @table_join.i_table_l_property_bridge_id = nil
    @table_join.i_table_r_property_bridge_id = nil
    @table_join.r_table_class_map_id = @class_maps[0].id
    @table_join.r_table_property_bridge_id = @property_bridges[@class_maps[0].id][0].id

    @owl_classes = RESOURCE_CLASSES.dup
    @owl_properties = PROPERTIES.dup
    @owl_object_properties = OBJECT_PROPERTIES.dup
    @owl_datatype_properties = DATATYPE_PROPERTIES.dup
    @subclass_of = {}
    @subproperty_of = {}

    namespace_uris = []
    namespace = {}
    NamespaceSetting.where(work_id: @work.id).each do |ns_setting|
      namespace_uris << ns_setting.namespace.uri
      namespace[ns_setting.namespace.uri] = ns_setting.namespace.prefix
    end
    Ontology.where(work_id: @work.id).each do |ontology|
      rdf_reader = RDF::Reader.for(ontology.file_format.to_sym)
      reader = rdf_reader.new(ontology.ontology)
      pos = nil
      reader.each_statement do |statement|
        if statement.predicate === RDF.type
          ns = prefixed_uri(statement.subject.to_s, namespace_uris, namespace)
              
          if statement.object === RDF::OWL.Class
            unless ns[:prefix].nil?
              unless @owl_classes.key?(ns[:prefix])
                @owl_classes[ns[:prefix]] = []
              end
              @owl_classes[ns[:prefix]] << ns[:vocab] unless @owl_classes[ns[:prefix]].include?(ns[:vocab])
            end
          elsif statement.object === RDF.Property
            unless ns[:prefix].nil?
              unless @owl_properties.key?(ns[:prefix])
                @owl_properties[ns[:prefix]] = []
              end
              @owl_properties[ns[:prefix]] << ns[:vocab] unless @owl_properties[ns[:prefix]].include?(ns[:vocab])
            end
          elsif statement.object === RDF::OWL.ObjectProperty
            unless ns[:prefix].nil?
              unless @owl_object_properties.key?(ns[:prefix])
                @owl_object_properties[ns[:prefix]] = []
              end
              @owl_object_properties[ns[:prefix]] << ns[:vocab] unless @owl_object_properties[ns[:prefix]].include?(ns[:vocab])
            end
          elsif statement.object === RDF::OWL.DatatypeProperty
            unless ns[:prefix].nil?
              unless @owl_datatype_properties.key?(ns[:prefix])
                @owl_datatype_properties[ns[:prefix]] = []
              end
              @owl_datatype_properties[ns[:prefix]] << ns[:vocab] unless @owl_datatype_properties[ns[:prefix]].include?(ns[:vocab])
            end
          end
        elsif statement.predicate === RDF::RDFS.subClassOf
          subject = prefixed_uri(statement.subject.to_s, namespace_uris, namespace)
          object = prefixed_uri(statement.object.to_s, namespace_uris, namespace)
          unless @subclass_of.key?(object[:uri])
            @subclass_of[object[:uri]] = []
          end
          @subclass_of[object[:uri]] << subject[:uri]
        elsif statement.predicate === RDF::RDFS.subPropertyOf
          subject = prefixed_uri(statement.subject.to_s, namespace_uris, namespace)
          object = prefixed_uri(statement.object.to_s, namespace_uris, namespace)
          unless @subproperty_of.key?(object[:uri])
            @subproperty_of[object[:uri]] = []
          end
          @subproperty_of[object[:uri]] << subject[:uri]
        end
      end
      reader.close!
    end

    if xhr?
      set_headers_for_cross_domain
      response_json
    else
    end
  end


  def upload_ontology
    @work = Work.find(params[:id])

    # Namespace
    params[:ns_prefix].zip(params[:ns_uri]).each do |prefix, uri|
      next if prefix.blank? || uri.blank?
      namespace = Namespace.where(prefix: prefix, uri: uri).first
      unless namespace
        namespace = Namespace.create!(prefix: prefix, uri: uri, is_default: false)
      end
      unless NamespaceSetting.exists?(work_id: @work.id, namespace_id: namespace.id)
        NamespaceSetting.create!(work_id: @work.id, namespace_id: namespace.id)
      end
    end
    
    file = params[:ontology_file]
    Ontology.create!(
      work_id: @work.id,
      ontology: file.read,
      file_name: file.original_filename,
      file_format: params[:file_format]
    )

    redirect_to er_path(@work.id)
  end

  
  def namespace
    @work = Work.find(params[:id])
    @class_map = ClassMap.first_class_map(@work.id)
    @namespaces = namespaces_by_namespace_settings(@work.id)
  end

  
  def subject_map_dialog
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

    respond_to do |format|
      format.html { render partial: 'subject_map_dialog' }
      format.js
    end
  end


  def predicate_object_map_dialog
    @property_bridge = PropertyBridge.find(params[:id])
    @work = @property_bridge.work
    validate_user(@work.id)

    @predicate_pbps = @property_bridge.predicate
    @object_pbps = @property_bridge.objects.first
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

    respond_to do |format|
      format.html {
        @mode = params[:mode]
        render partial: 'predicate_object_map_dialog'
      }
      format.js
    end
  end


  def table_join_dialog
    @table_join = TableJoin.find(params[:id])
    validate_user(@table_join.work.id)
    
    @target = params[:target]

    @class_map = @table_join.class_map
    @property_bridge = @table_join.property_bridge

    @subject_cmps = ClassMapPropertySetting.where(
      class_map_id: @class_map.id,
      class_map_property_id: ClassMapProperty.for_resource_identity.map(&:id)
    ).first

    @rdf_type_cmps = ClassMapPropertySetting.where(
      class_map_id: @class_map.id,
      class_map_property_id: ClassMapProperty.rdf_type.id
    )

    @resource_label_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: @class_map.property_bridge_for_resource_label.id,
      property_bridge_property_id: PropertyBridgeProperty.literal_pattern.id
    ).first

    @resource_label_lang_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: @class_map.property_bridge_for_resource_label.id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id
    ).first

    @condition_cmps = ClassMapPropertySetting.where(
      class_map_id: @class_map.id,
      class_map_property_id: ClassMapProperty.condition.id
    ).first
    if @condition_cmps.nil?
      @condition_cmps = ClassMapPropertySetting.create(
        class_map_id: @class_map.id,
        class_map_property_id: ClassMapProperty.condition.id,
        value: ''
      )
    end

    @predicate_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: @property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.property.id
    )

    @object_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: @property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.object_properties.map(&:id)
    ).first

    @lang_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: @property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id
    ).first

    @datatype_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: @property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.datatype.id
    ).first

    @condition_pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: @property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.condition.id
    ).first
    if @condition_pbps.nil?
      @condition_pbps = PropertyBridgePropertySetting.create(
        property_bridge_id: @property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.condition.id
      )
    end

    respond_to do |format|
      format.html { render partial: 'table_join_dialog' }
      format.js
    end
  end


  def save_xml_dialog
    @work = Work.find(params[:id])
    respond_to do |format|
      format.html { render partial: 'save_xml_dialog' }
      format.js
    end
  end


  def server_load
    work = Work.find(params[:id])

    require 'togo_mapper/er/xml_generator'
    xml_generator = TogoMapper::ER::XmlGenerator.new(work)
    render xml: xml_generator.generate
  end


  def table_positions
    if xhr?
      set_headers_for_cross_domain
      if request.get?
        response_table_positions
      elsif request.patch?
        update_table_positions
      end
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


  def prefixed_uri(uri, namespace_uris, namespace)
    prefix = nil
    vocab = nil

    namespace_uris.each do |ns_uri|
      if uri[0 .. ns_uri.size - 1] == ns_uri
        prefix = namespace[ns_uri]
        vocab = uri[ns_uri.size .. -1]
        uri = "#{prefix}:#{vocab}"
        break
      end
    end

    if prefix.nil?
      pos = nil
      slash_pos = uri.rindex('/')
      sharp_pos = uri.rindex('#')
      if !slash_pos.nil? && !sharp_pos.nil?
        if slash_pos > sharp_pos
          pos = slash_pos
        else
          pos = sharp_pos
        end
      elsif slash_pos.nil? && !sharp_pos.nil?
        pos = sharp_pos
      elsif !slash_pos.nil? && sharp_pos.nil?
        pos = slash_pos
      end
    end
            
    unless pos.nil?
      namespace = uri[0 .. pos]
      ns = Namespace.where(uri: namespace).first
      if ns
        namespace_setting = NamespaceSetting.where(work_id: @work.id, namespace_id: ns.id).first
        if namespace_setting
          namespace = ns.prefix
        end
      end
      vocab = uri[pos + 1 .. - 1]
    end

    if vocab.nil?
      vocab = uri
    end

    { prefix: prefix, vocab: vocab, uri: uri }
  end

  
  def find_property_type(property)
    prefix, name = property.split(':')
    prefix = prefix.to_sym
    if !OBJECT_PROPERTIES[prefix].nil? && OBJECT_PROPERTIES[prefix].include?(name)
      'object-property'
    elsif !DATATYPE_PROPERTIES[prefix].nil? && DATATYPE_PROPERTIES[prefix].include?(name)
      'datatype-property'
    else
      'property'
    end
  end


  def response_json
    data = common_json_data("100", "")
    data[:tables] = []
    @class_maps.each do |class_map|
      table = {
        id: class_map.id,
        name: class_map.table_name,
        enable: class_map.enable,
        xpos: class_map.er_xpos,
        ypos: class_map.er_ypos,
        columns: []
      }
      @property_bridges[class_map.id].each do |property_bridge|
        table[:columns] << {
          id: property_bridge.id,
          name: property_bridge.column_name,
          enable: property_bridge.enable
        }
      end
      data[:tables] << table
    end

    render_json(data)
  end


  def response_table_positions
    @work = Work.find(params[:id])
    begin
      db_conn = DbConnection.where(work_id: @work.id).first
      db = TogoMapper::DB.new(db_conn.connection_config)
    rescue => e
      flash[:error] = e.message.force_encoding("UTF-8")
      redirect_to :menu
      return
    end
    set_instance_variables_for_table_and_column(db_conn)
    
    data = common_json_data("100", "")
    data[:tables] = {}
    @class_maps.each do |class_map|
      data[:tables][class_map.id] = {
        xpos: class_map.er_xpos,
        ypos: class_map.er_ypos,
      }
    end

    render_json(data)
  end

  
  def update_table_positions
    validate_user
    
    json = JSON.parse(params[:tables])
    json.each do |table|
      class_map = ClassMap.find(table['id'])
      class_map.er_xpos = table['x']
      class_map.er_ypos = table['y']
      class_map.save!
    end

    render_json(common_json_data('100', 'Table position has been saved successfully.'))
  end

end
