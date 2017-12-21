module ErHelper

  def datatype_property?
    @property_type.nil? || @property_type == 'property' || @property_type == 'datatype-property'
  end

  def object_property?
    @property_type.nil? || @property_type == 'property' || @property_type == 'object-property'
  end

  def format_selector_option_tags
    option_tags = []
    if object_property?
      [PropertyBridgeProperty.uri_pattern, PropertyBridgeProperty.uri_column].each do |pbp|
	option_tags << [pbp.label, pbp.id]
      end
    end
    if datatype_property?
      [PropertyBridgeProperty.literal_pattern, PropertyBridgeProperty.literal_column].each do |pbp|
	option_tags << [pbp.label, pbp.id]
      end
    end

    option_tags
  end
  
  def pattern_value(property_bridge_property_setting)
    property_bridge_property = property_bridge_property_setting.property_bridge_property
    if property_bridge_property.property == 'd2rq:pattern' || property_bridge_property.property == 'd2rq:uriPattern'
      property_bridge_property_setting.value
    else
      property_bridge = property_bridge_property_setting.property_bridge
      "@@#{property_bridge.class_map.table_name}.#{property_bridge.column_name}@@"
    end
  end

end
