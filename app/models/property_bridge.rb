class PropertyBridge < ApplicationRecord

  scope :by_work_id, ->(work_id) {
    where(work_id: work_id).order(:id)
  }

  scope :by_name, ->(name) {
    where(map_name: name).first
  }

  scope :user_defined, ->(work_id) {
    where(work_id: work_id, user_defined: true)
  }

  belongs_to :work
  belongs_to :class_map
  has_one    :property_bridge_type
  has_many   :property_bridge_property_settings, dependent: :destroy


  before_create do |pb|
    if pb.property_bridge_type_id != PropertyBridgeType.bnode.id && pb.map_name.nil?
      pb.map_name = generate_map_name
    end
  end


  def predicate
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.predicate_properties.map{|p| p.id}
    )
  end


  def object
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.object_properties.map{|p| p.id}
    )
  end


  def pbps_for_refers_to_class_map
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.refers_to_class_map.id
    ).first
  end
  
  
  def pbps_for_lang
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.lang.id
    ).first
  end


  def pbps_for_datatype
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.datatype.id
    ).first
  end


  def pbps_for_condition
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.condition.id
    ).first
  end


  def object_for_join
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.join_object_properties.map(&:id)
    ).first
  end


  def optional_properties
    PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.optional_properties.map{|p| p.id}
    )
  end


  def for_column?
    property_bridge_type_id == PropertyBridgeType.column.id
  end


  def for_label?
    property_bridge_type_id == PropertyBridgeType.label.id
  end


  def for_bnode?
    property_bridge_type_id == PropertyBridgeType.bnode.id
  end


  def has_property?
    property_bridge_property_setting = PropertyBridgePropertySetting.where(
      property_bridge_id: id,
      property_bridge_property_id: PropertyBridgeProperty.property.id
    ).first
    if property_bridge_property_setting && !property_bridge_property_setting.value.blank?
      true
    else
      false
    end
  end


  def generate_map_name
    class_map = ClassMap.find(self.class_map_id)
    if class_map.table_join_id
      table_join = TableJoin.find(class_map.table_join_id)
    end

    if self.for_column?
      if class_map.table_join_id
        name = "join-#{table_join.l_table.table_name}.#{table_join.l_column.column_name}-#{table_join.r_table.table_name}.#{table_join.r_column.column_name}"
      else
        name = "#{class_map.table_name}.#{self.column_name}"
      end
    elsif self.for_label?
      if class_map.table_join_id
        name = "label-join-#{table_join.l_table.table_name}.#{table_join.l_column.column_name}-#{table_join.r_table.table_name}.#{table_join.r_column.column_name}"
      else
        name = "label-#{class_map.table_name}"
      end
    end

    if PropertyBridge.exists?(work_id: self.work_id, map_name: name)
      number = 1
      while PropertyBridge.exists?(work_id: self.work_id, map_name: "#{name}-#{number}")
        number += 1
      end

      name = "#{name}-#{number}"
    end

    name
  end


  def query_where_condition
    pbps = pbps_for_condition
    if pbps
      pbps.value.to_s
    else
      ""
    end
  end


  def real_column_name
    if column_name.to_s[0 .. 3] == 'col_'
      column_name[4 .. -1]
    else
      column_name
    end
  end
  
end
