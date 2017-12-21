class ClassMapProperty < ApplicationRecord

  default_scope { order(id: :asc) }

  scope :by_property, ->(property) { where(property: "d2rq:#{property}").first }

  scope :not_resource_identity, -> {
    where.not(property: ["d2rq:dataStorage", "d2rq:uriPattern", "d2rq:uriColumn", "d2rq:uriSqlExpression", "d2rq:bNodeIdColumns", "d2rq:constantValue"]).order("UPPER(label)")
  }

  scope :default_property, -> { where(property: "d2rq:uriPattern").first }

  scope :uri_pattern, -> { where(property: "d2rq:uriPattern").first }
  scope :uri_column, -> { where(property: "d2rq:uriColumn").first }
  scope :bnode, -> { where(property: "d2rq:bNodeIdColumns").first }

  scope :rdf_type, -> { where(property: "d2rq:class").first }
  scope :condition, -> { where(property: "d2rq:condition").first }

  has_many :class_map_property_settings


  class << self
    
    def for_resource_identity
      [ uri_pattern, uri_column ]
    end
    
  end

  
  def subject_map_format?
    property == 'd2rq:uriPattern' || property == 'd2rq:uriColumn'
  end

end
