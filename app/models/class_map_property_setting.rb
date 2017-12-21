class ClassMapPropertySetting < PropertySetting

  belongs_to :class_map
  belongs_to :class_map_property

  before_save :to_relative_uri


  def base_uri
    class_map.work.base_uri
  end


  def uri_pattern?
    class_map_property_id == ClassMapProperty.uri_pattern.id
  end


  def subject?
    resource_identity_class_map_property_ids = ClassMapProperty.for_resource_identity.map(&:id)
    resource_identity_class_map_property_ids << ClassMapProperty.bnode.id
    resource_identity_class_map_property_ids.include?(class_map_property_id)
  end


  def rdf_type?
    class_map_property_id == ClassMapProperty.rdf_type.id
  end


  def condition?
    class_map_property_id == ClassMapProperty.condition.id
  end

end
