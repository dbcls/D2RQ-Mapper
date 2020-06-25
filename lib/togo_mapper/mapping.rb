require 'togo_mapper/db'
require 'togo_mapper/d2rq'

module TogoMapper
module Mapping
  include TogoMapper::D2RQ

  def init_mapping(db_conn)
    db_client = TogoMapper::DB.new(db_conn.connection_config)
    db_client.tables.each do |table_name|
      columns = db_client.columns(table_name)
      init_mapping_for_table(table_name, columns)
    end
    db_client.close
  end


  def init_mapping_for_table(table_name, columns)
    default_class_map_property = ClassMapProperty.default_property

    source_cm = ClassMap.find_by(work_id: @work.id, table_name: table_name)

    class_map = ClassMap.create!(
      work_id: @work.id,
      table_name: table_name,
      enable: true
    )

    # Table-ClassMapID Mapping
    if source_cm
      TableClassMap.create!(table_id: source_cm.id, class_map_id: class_map.id)
    else
      TableClassMap.create!(table_id: class_map.id, class_map_id: class_map.id)
    end

    # Method to generate subject URI (URI pattern, URI column, Constant URI)
    ClassMapPropertySetting.create!(
      class_map_id: class_map.id,
      class_map_property_id: default_class_map_property.id,
      value: default_subject_uri(table_name, columns[0])
    )

    # rdf:type (d2rq:class)
    ClassMapPropertySetting.create!(
      class_map_id: class_map.id,
      class_map_property_id: ClassMapProperty.rdf_type.id,
      value: default_class_map_rdf_type(class_map)
    )

    # columns (PropertyBridges)
    columns.each do |column|
      init_mapping_for_column(class_map, table_name, column)
    end

    # rdfs:label
    create_models_for_resource_label(class_map)
    
    class_map
  end


  def init_mapping_for_column(class_map, table_name, column, value = {})
    property_bridge_type_for_column = PropertyBridgeType.column
    default_property_bridge_object_property = PropertyBridgeProperty.object_default

    source_property_bridge = PropertyBridge.find_by(class_map_id: class_map.id, column_name: column)

    # Property Bridge
    property_bridge = create_property_bridge(@work.id, class_map.id, table_name, column, property_bridge_type_for_column.id)

    # Column-PropertyBridgeID Mapping
    if source_property_bridge
      ColumnPropertyBridge.create!(column_id: source_property_bridge.id, property_bridge_id: property_bridge.id)
    else
      ColumnPropertyBridge.create!(column_id: property_bridge.id, property_bridge_id: property_bridge.id)
    end

    # Relation of ClassMap
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.by_property("belongsToClassMap").id,
      value: class_map.map_name
    )
    
    # Predicates
    if value.key?(:predicates)
      predicates = value[:predicates]
    else
      predicates = [
          { 'value' => default_predicate_uri(table_name, column) }
      ]
    end
    predicates.each do |predicate|
      PropertyBridgePropertySetting.create!(
          property_bridge_id: property_bridge.id,
          property_bridge_property_id: PropertyBridgeProperty.property.id,
          value: predicate['value']
      )
    end

    # Object
    object = value.key?(:object) ? value[:object] : default_property_bridge_property_value(table_name, column)
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: default_property_bridge_object_property.id,
      value: object
    )

    # Language
    language = value.key?(:language) ? value[:language] : ''
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id,
      value: language
    )

    # Datatype
    datatype = value.key?(:datatype) ? value[:datatype] : ''
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.datatype.id,
      value: datatype
    )

    # WHERE condition
    condition = value.key?(:where_condition) ? value[:where_condition] : ''
    PropertyBridgePropertySetting.create!(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.condition.id,
        value: condition
    )

    property_bridge
  end


  def create_property_bridge(work_id, class_map_id, table, column, property_bridge_type_id)
    PropertyBridge.create!(
      work_id: work_id,
      class_map_id: class_map_id,
      user_defined: false,
      column_name: column,
      enable: true,
      property_bridge_type_id: property_bridge_type_id
    )
  end


  def create_models_for_resource_label(class_map, value = {})
    model = {}

    model[:property_bridge] = PropertyBridge.create!(
      work_id: class_map.work.id,
      class_map_id: class_map.id,
      user_defined: false,
      column_name: nil,
      enable: true,
      property_bridge_type_id: PropertyBridgeType.label.id
    )

    # belongsToClassMap
    PropertyBridgePropertySetting.create!(
      property_bridge_id: model[:property_bridge].id,
      property_bridge_property_id: PropertyBridgeProperty.by_property("belongsToClassMap").id,
      value: class_map.map_name
    )

    model[:pbps_predicate] = PropertyBridgePropertySetting.create!(
      property_bridge_id: model[:property_bridge].id,
      property_bridge_property_id: PropertyBridgeProperty.property.id,
      value: default_resource_label_predicate
    )

    model[:pbps_object] = PropertyBridgePropertySetting.create!(
      property_bridge_id: model[:property_bridge].id,
      property_bridge_property_id: PropertyBridgeProperty.literal_pattern.id,
      value: value.key?(:label) ? value[:label] : default_resource_label_object(class_map)
    )

    model[:pbps_lang] = PropertyBridgePropertySetting.create!(
      property_bridge_id: model[:property_bridge].id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id,
      value: value.key?(:lang) ? value[:lang] : default_resource_label_lang
    )

    model
  end


  def delete_work(work_id)
    work = Work.find(work_id)

    DbConnection.where(work_id: work.id).destroy_all

    ClassMapPropertySetting.where(
        class_map_id: work.class_maps.map(&:id)
    ).destroy_all

    PropertyBridgePropertySetting.where(
        property_bridge_id: work.property_bridges.map(&:id)
    ).destroy_all

    TableJoin.where(work_id: work.id).destroy_all

    NamespaceSetting.where(work_id: work.id).destroy_all

    ClassMap.where(work_id: work.id).destroy_all

    PropertyBridge.where(work_id: work.id).destroy_all

    work.destroy
  end


  def maintain_consistency_with_rdb
    deleted_class_maps = []
    new_tables = []
    deleted_property_bridges = []
    new_columns = []

    db_conn = DbConnection.where(work_id: @work.id).first
    db = TogoMapper::DB.new(db_conn.connection_config)
    tables = db.tables

    @work.class_maps.each do |class_map|
      if class_map.table_name.present?
        if tables.include?(class_map.table_name)
          columns = db.columns(class_map.table_name)
          class_map.property_bridges.each do |property_bridge|
            next if property_bridge.only_pattern?
            if property_bridge.column_name.present? && !columns.include?(property_bridge.column_name)
              deleted_property_bridges << property_bridge
            end
          end

          columns.each do |column_name|
            unless PropertyBridge.exists?(work_id: @work.id, class_map_id: class_map.id, column_name: column_name)
              new_columns << { class_map: class_map, table_name: class_map.table_name, column_name: column_name }
            end
          end
        else
          deleted_class_maps << class_map
        end
      end
    end

    tables.each do |table_name|
      unless ClassMap.exists?(work_id: @work.id, table_name: table_name)
        new_tables << table_name
      end
    end

    deleted_class_maps.each do |class_map|
      class_map.destroy
    end

    deleted_property_bridges.each do |property_bridge|
      property_bridge.destroy
    end

    new_tables.each do |table_name|
      init_mapping_for_table(table_name, db.columns(table_name))
    end

    new_columns.each do |new_column|
      init_mapping_for_column(new_column[:class_map], new_column[:table_name], new_column[:column_name])
    end
  end


  def read_ontologies
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
      ns = ::Namespace.where(uri: namespace).first
      if ns
        namespace_setting = NamespaceSetting.find_by(work_id: @work.id, namespace_id: ns.id)
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


  def ontology_uri_for_disp(work_id, prefix, vocab)
    namespace = ::Namespace.find_by(prefix: prefix)
    if namespace
      if namespace.is_default
        "#{prefix}:#{vocab}"
      else
        "#{prefix}#{vocab}"
      end
    else
      "#{prefix}#{vocab}"
    end
  end


  def default_subject_uri(table_name, column_name)
    "<#{table_name}/@@#{table_name}.#{column_name}@@>"
  end
  

  def default_property_bridge_property_value(table_name, column_name)
    "#{table_name}.#{column_name}"
  end


  def default_predicate_uri(table_name, column_name)
    "#{table_name}##{column_name}"
  end

end
end
