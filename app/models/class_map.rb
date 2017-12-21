class ClassMap < ApplicationRecord

  default_scope { order(id: :asc) }

  scope :by_work_id, ->(work_id) {
    where(work_id: work_id).order(:table_name)
  }

  scope :by_name, ->(name) {
    where(map_name: name).first
  }

  scope :table_derived, ->(work_id) {
    where("work_id=#{work_id} AND table_join_id IS NULL AND bnode_id IS NULL").order(:table_name)
  }

  scope :user_defined, ->(work_id) {
    where("work_id=#{work_id} AND table_name IS NULL")
  }

  has_many   :class_map_property_settings, dependent: :destroy
  has_many   :property_bridges, dependent: :destroy
  has_one    :table_join
  belongs_to :work


  before_create do |cm|
    cm.map_name = generate_map_name
  end


  class << self
    def first_class_map(work_id)
      ClassMap.where(work_id: work_id).order(:table_name).first
    end

    def for_er(work_id)
      ClassMap.where(work_id: work_id, table_join_id: nil, bnode_id: nil).order(:id)
    end
  end

  
  def property_setting_for_resource_identity
    ClassMapPropertySetting.where(
      class_map_id: self.id,
      class_map_property_id: ClassMapProperty.for_resource_identity.map(&:id) + [ClassMapProperty.bnode.id]
    ).first
  end


  def property_settings_for_class
    ClassMapPropertySetting.where(
      class_map_id: id,
      class_map_property_id: ClassMapProperty.rdf_type.id
    ).order(:id)
  end


  def column_property_bridges
    PropertyBridge.where("class_map_id=? AND column_name IS NOT NULL", self.id)
  end


  def property_bridges_for_column
    if for_join?
      table_join.l_table.property_bridges_for_column + table_join.r_table.property_bridges_for_column
    else
      PropertyBridge.where(class_map_id: id, property_bridge_type_id: PropertyBridgeType.column.id).order(:id)
    end
  end


  def property_bridges_for_bnode
    PropertyBridge.where(class_map_id: id, property_bridge_type_id: PropertyBridgeType.bnode.id)
  end


  def property_bridge_for_resource_label
    property_bridge = PropertyBridge.where(
      class_map_id: self.id,
      property_bridge_type_id: PropertyBridgeType.label.id
    ).first

    if property_bridge
      condition = {
        property_bridge_id: property_bridge.id,
        property_bridge_property_id: PropertyBridgeProperty.property,
        value: "rdfs:label"
      }
      if PropertyBridgePropertySetting.exists?(condition)
        property_bridge
      else
        nil
      end
    else
      nil
    end
  end


  def predicate_property
    class_map_property_ids = ClassMapProperty.for_resource_identity.map{ |model| model.id }
    class_map_property_setting_for_predicate = class_map_property_settings.select { |model| class_map_property_ids.include?(model.class_map_property_id) }

    class_map_property_setting_for_predicate[0]
  end


  def table_derived?
    table_join_id.nil?
  end


  def for_join?
    !table_join_id.nil?
  end


  def for_bnode?
    !bnode_id.nil?
  end


  def cmps_for_condition
    ClassMapPropertySetting.where(
      class_map_id: self.id,
      class_map_property_id: ClassMapProperty.condition.id
    ).first
  end


  def query_where_condition
    cmps = cmps_for_condition
    if cmps
      cmps.value.to_s
    else
      ""
    end
  end


  def divide_property_bridge_by_condition
    hash = {:with_condition => [], :without_condition => []}
    property_bridges.each do |pb|
      if pb.query_where_condition.blank?
        hash[:without_condition] << pb
      else
        hash[:with_condition] << pb
      end
    end

    hash
  end


  def pk_column_name
    property_bridges = PropertyBridge.where(
      work_id: self.work_id,
      class_map_id: self.id
    ).order(:id)

    if property_bridges
      property_bridges[0].column_name
    else
      ""
    end
  end


  def generate_map_name
    if table_join_id
      table_join = TableJoin.find(table_join_id)
      name = "join-#{table_join.l_table.table_name}-#{table_join.r_table.table_name}"
    elsif bnode_id
      name = "_bnode-#{self.table_name}"
      if bnode_id > 0
        name = "#{name}-#{bnode_id}"
      end
    else
      name = self.table_name
    end

    if ClassMap.exists?(work_id: self.work_id, map_name: name)
      number = 1
      while ClassMap.exists?(work_id: self.work_id, map_name: "#{name}-#{number}")
        number += 1
      end

      name = "#{name}-#{number}"
    end

    name
  end


  def bnode_id_columns
    cmps = ClassMapPropertySetting.where(
      class_map_id: self.id,
      class_map_property_id: ClassMapProperty.bnode.id
    ).first

    cmps.value
  end


  def bnode_name_tmpl_for_r2rml
    blank_node = BlankNode.find(bnode_id)
    property_bridge = PropertyBridge.find(blank_node.property_bridge_id)

    "#{map_name}-{#{property_bridge.column_name}}"
  end


  def has_property_bridge?
    if for_join? || for_bnode?
      !PropertyBridge.where(class_map_id: self.id, enable: true).select{ |property_bridge| !property_bridge.for_label? }.empty?
    else
      PropertyBridge.exists?(class_map_id: self.id, enable: true)
    end
  end

end
