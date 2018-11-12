module TogoMapper::D2RQ::Bnode
  include TogoMapper::Mapping
  include TogoMapper::D2RQ

  def create_blank_node(property_bridge_ids, class_map_id = nil)
    blank_node = nil

    ActiveRecord::Base.transaction do
      class_map = get_class_map(property_bridge_ids)
      property_bridge = PropertyBridge.find(property_bridge_ids[0])

      blank_node = BlankNode.create!(
          work_id: @work.id,
          class_map_id: class_map_id || class_map.id,
          property_bridge_id: property_bridge_ids[0],
          property_bridge_ids: property_bridge_ids.join(',')
      )

      bnode_class_map = ClassMap.create!(
          work_id: @work.id,
          table_name: class_map.table_name,
          enable: true,
          bnode_id: blank_node.id
      )

      # ClassMapPropertySetting for d2rq:bNodeIdColumns
      ClassMapPropertySetting.create!(
          class_map_id: bnode_class_map.id,
          class_map_property_id: ClassMapProperty.bnode.id,
          value: bnode_id_columns_value(property_bridge_ids)
      )

      # ClassMapPropertySetting for d2rq:class (rdf:type)
      ClassMapPropertySetting.create!(
          class_map_id: bnode_class_map.id,
          class_map_property_id: ClassMapProperty.rdf_type.id,
          value: default_class_map_rdf_type(bnode_class_map)
      )

      # PropertyBridge for blank node
      bnode_property_bridge = PropertyBridge.create!(
          work_id: @work.id,
          map_name: "#{bnode_class_map.map_name}-pb",
          class_map_id: class_map.id,
          user_defined: true,
          enable: true,
          property_bridge_type_id: PropertyBridgeType.bnode.id,
          bnode_id: blank_node.id
      )

      # PropertyBridgePropertySetting for d2rq:belongsToClassMap of blank node
      PropertyBridgePropertySetting.create!(
          property_bridge_id: bnode_property_bridge.id,
          property_bridge_property_id: PropertyBridgeProperty.by_property('belongsToClassMap').id,
          value: class_map.map_name
      )

      # PropertyBridgePropertySetting for d2rq:property of blank node
      PropertyBridgePropertySetting.create!(
          property_bridge_id: bnode_property_bridge.id,
          property_bridge_property_id: PropertyBridgeProperty.property.id,
          value: "#{class_map.table_name}-bnode##{property_bridge.column_name}"
      )

      # PropertyBridgePropertySetting for d2rq:refersToClassMap
      PropertyBridgePropertySetting.create!(
          property_bridge_id: bnode_property_bridge.id,
          property_bridge_property_id: PropertyBridgeProperty.by_property('refersToClassMap').id,
          value: "map:#{bnode_class_map.map_name}"
      )

      # Columns (PropertyBridges) in blank node
      db_client = TogoMapper::DB.new(@work.db_connection.connection_config)
      db_client.columns(class_map.table_name).each do |column_name|
        init_mapping_for_column(bnode_class_map, bnode_class_map.table_name, column_name)
      end

      # Table-ClassMapID Mapping
      if bnode_class_map
        TableClassMap.create!(table_id: bnode_class_map.id, class_map_id: bnode_class_map.id)
      end

    end

    blank_node
  end


  def destroy_blank_node(blank_node)
    ActiveRecord::Base.transaction do
      bnode_class_map = ClassMap.where(bnode_id: blank_node.id).first
      bnode_property_bridge = PropertyBridge.where(bnode_id: blank_node.id).first

      PropertyBridge.where(class_map_id: bnode_class_map.id).each do |property_bridge|
        PropertyBridgePropertySetting.destroy_all(property_bridge_id: property_bridge.id)
        property_bridge.destroy
      end

      PropertyBridgePropertySetting.destroy_all(property_bridge_id: bnode_property_bridge.id)
      ClassMapPropertySetting.destroy_all(class_map_id: bnode_class_map.id)

      bnode_property_bridge.destroy
      bnode_class_map.destroy
      blank_node.destroy
    end
  end


  def bnode_id_columns_value(property_bridge_ids)
    property_bridge_ids.map{ |property_bridge_id|
      property_bridge = PropertyBridge.find(property_bridge_id)
      "#{property_bridge.class_map.table_name}.#{property_bridge.column_name}"
    }.join(',')
  end


  def get_class_map(property_bridge_ids)
    PropertyBridge.find(property_bridge_ids[0]).class_map
  end

end
