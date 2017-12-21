class TableJoin < ApplicationRecord

  belongs_to :l_table, class_name: 'ClassMap', foreign_key: 'l_table_class_map_id'
  belongs_to :l_column, class_name: 'PropertyBridge', foreign_key: 'l_table_property_bridge_id'
  belongs_to :i_table, class_name: 'ClassMap', foreign_key: 'i_table_class_map_id', optional: true
  belongs_to :i_l_column, class_name: 'PropertyBridge', foreign_key: 'i_table_l_property_bridge_id', optional: true
  belongs_to :i_r_column, class_name: 'PropertyBridge', foreign_key: 'i_table_r_property_bridge_id', optional: true
  belongs_to :r_table, class_name: 'ClassMap', foreign_key: 'r_table_class_map_id'
  belongs_to :r_column, class_name: 'PropertyBridge', foreign_key: 'r_table_property_bridge_id'

  belongs_to :work
  belongs_to :class_map, optional: true
  belongs_to :property_bridge, optional: true


  class << self
    def by_work_id(work_id)
      TableJoin.where(work_id: work_id).order(:id).select(&:correct?)
    end
  end
  

  def correct?
    !l_table.nil? && !r_table.nil? && !class_map.nil? && !property_bridge.nil?
  end


  def multiple_join?
    !i_table_class_map_id.nil?
  end


  def label
    if multiple_join?
      l = "#{l_table.table_name}.#{l_column.column_name} = #{i_table.table_name}.#{i_l_column.column_name}, #{i_table.table_name}.#{i_r_column.column_name} = #{r_table.table_name}.#{r_column.column_name}"
    else
      l = "#{l_table.table_name}.#{l_column.column_name} = #{r_table.table_name}.#{r_column.column_name}"
    end

    l
  end


  def label_for_join_dialog
    if multiple_join?
      l = "#{l_table.table_name}.#{l_column.column_name} - [#{i_table.table_name}] - #{r_table.table_name}.#{r_column.column_name}"
    else
      l = "#{l_table.table_name}.#{l_column.column_name} = #{r_table.table_name}.#{r_column.column_name}"
    end

    l
  end


  def class_map_for_subject
    condition = {
      class_map_id: self.class_map_id,
      class_map_property_id: ClassMapProperty.for_resource_identity.map(&:id)
    }

    if ClassMapPropertySetting.exists?(condition)
      self.class_map
    else
      self.l_table
    end
  end


  def predicate
    pbps_for_predicate = PropertyBridgePropertySetting.where(
      property_bridge_id: self.property_bridge_id,
      property_bridge_property_id: PropertyBridgeProperty.property.id
    ).first

    pbps_for_predicate.value
  end


  def property_bridge_property_setting_for_object
    PropertyBridgePropertySetting.where(
      property_bridge_id: self.property_bridge_id,
      property_bridge_property_id: PropertyBridgeProperty.join_object_properties.map(&:id)
    ).first
  end

end
