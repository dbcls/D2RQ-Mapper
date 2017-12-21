class BlankNode < ApplicationRecord

  def property_bridge
    class_map = ClassMap.find(class_map_id)
    PropertyBridge.where(class_map_id: class_map.id, bnode_id: id).first
  end


  def property
    pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.property.id,
    ).first

    pbps.value
  end


  def predicates
    PropertyBridgePropertySetting.where(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.property.id
    )
  end


  def property_bridge_property_setting
  end


  def pbps_for_condition
    pbps = PropertyBridgePropertySetting.where(
      property_bridge_id: property_bridge.id,
      property_bridge_property_id: PropertyBridgeProperty.condition.id
    ).first

    unless pbps
      pbps = PropertyBridgePropertySetting.create(
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.condition.id,
        value: ""
      )
    end

    pbps
  end


  def label
    class_map = ClassMap.find(class_map_id)
    property_bridge = PropertyBridge.find(property_bridge_id)

    "#{class_map.table_name}.#{property_bridge.column_name}"
  end


  def to_hash
    {
        id: id,
        work_id: work_id,
        property_bridge_ids: property_bridge_ids.split(',').map{ |id| id.to_i }
    }
  end

end
