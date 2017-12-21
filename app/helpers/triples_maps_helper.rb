module TriplesMapsHelper

  def column_rdf_button_class(property_bridge)
    if property_bridge && property_bridge.enable
      "btn btn-primary btn-rdf btn-rdf-disable"
    else
      "btn btn-default btn-rdf btn-rdf-enable"
    end
  end


  def new_pb_instance
    property_bridge = PropertyBridge.new
    property_bridge.work_id = @property_bridge.work_id
    property_bridge.class_map_id = @class_map.id
    property_bridge.column_name = @property_bridge.column_name
    property_bridge.enable = true
    property_bridge.property_bridge_type_id = @property_bridge.property_bridge_type_id

    property_bridge.save!

    # PropertyBridgePropertySetting for d2rq:belongsToClassMap
    PropertyBridgePropertySetting.create!(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.by_property('belongsToClassMap').id,
      value: @class_map.map_name
    )

    property_bridge
  end


  def new_pbps_hash(property_bridge_id)
    predicate = PropertyBridgePropertySetting.new
    predicate.property_bridge_id = property_bridge_id
    predicate.property_bridge_property_id = PropertyBridgeProperty.by_property('property').id
    predicate.value = ''
    predicate.save!

    object = PropertyBridgePropertySetting.new
    object.property_bridge_id = property_bridge_id
    object.property_bridge_property_id = PropertyBridgeProperty.literal_column.id
    object.value = ''
    object.save!

    language = PropertyBridgePropertySetting.new
    language.property_bridge_id = property_bridge_id
    language.property_bridge_property_id = PropertyBridgeProperty.lang.id
    language.value = ''
    language.save!

    datatype = PropertyBridgePropertySetting.new
    datatype.property_bridge_id = property_bridge_id
    datatype.property_bridge_property_id = PropertyBridgeProperty.datatype.id
    datatype.value = ''
    datatype.save!

    condition = PropertyBridgePropertySetting.new
    condition.property_bridge_id = property_bridge_id
    condition.property_bridge_property_id = PropertyBridgeProperty.condition.id
    condition.value = ''
    condition.save!

    {
      predicates: [ predicate ],
      object: object,
      language: language,
      datatype: datatype,
      condition: condition
    }
  end


  def disp_table_selector?(options_for_table_selector)
    return true if options_for_table_selector.size > 1
    return false if options_for_table_selector.empty?

    options_for_table_selector[0][1].size > 1
  end
  
end
