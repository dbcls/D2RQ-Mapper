class PropertyBridgeProperty < ApplicationRecord

  default_scope { order(id: :asc) }

  scope :by_property, ->(property) {
    where(property: "d2rq:#{property}").first
  }

  scope :subject_property, -> { where(property: "d2rq:belongsToClassMap").first }

  scope :predicate_properties, -> { where(property: ["d2rq:property", "d2rq:dynamicProperty"]) }

  scope :uri_object_properties, -> { where(property: ["d2rq:uriColumn", "d2rq:uriPattern"]) }

  scope :optional_properties, -> { where.not(property: ["d2rq:belongsToClassMap", "d2rq:property", "d2rq:dynamicProperty", "d2rq:column", "d2rq:pattern", "d2rq:sqlExpression", "d2rq:uriColumn", "d2rq:uriPattern", "d2rq:uriSqlExpression", "d2rq:constantValue", "d2rq:refersToClassMap", "d2rq:lang", "d2rq:datatype"]).reorder("UPPER(label)") }

  scope :property, -> { where(property: "d2rq:property").first }

  scope :refers_to_class_map, -> { where(property: "d2rq:refersToClassMap").first }

  scope :lang, -> { where(property: "d2rq:lang").first }
  scope :datatype, -> { where(property: "d2rq:datatype").first }
  scope :condition, -> { where(property: "d2rq:condition").first }

  scope :predicate_default, -> { where(property: "d2rq:property").first }
  scope :object_default, -> { where(property: "d2rq:column").first }

  scope :uri_pattern, -> { where(property: "d2rq:uriPattern").first }
  scope :uri_column, -> { where(property: "d2rq:uriColumn").first }
  scope :literal_pattern, -> { where(property: "d2rq:pattern").first }
  scope :literal_column, -> { where(property: "d2rq:column").first }

  has_many :property_bridge_property_settings


  class << self

    def subject_format_properties
      [ uri_pattern, uri_column ]
    end

    
    def object_properties
      [ uri_pattern, uri_column, literal_pattern, literal_column ]
    end


    def join_object_properties
      where(property: "d2rq:refersToClassMap") + where(property: ["d2rq:column", "d2rq:pattern", "d2rq:uriColumn", "d2rq:uriPattern"]).order(:id)
    end

  end

end
