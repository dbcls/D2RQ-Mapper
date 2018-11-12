# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# namespaces
Namespace.find_or_create_by(
  prefix: "map",
  uri: "#",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "d2rq",
  uri: "http://www.wiwiss.fu-berlin.de/suhl/bizer/D2RQ/0.1#",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "jdbc",
  uri: "http://d2rq.org/terms/jdbc/",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "xsd",
  uri: "http://www.w3.org/2001/XMLSchema#",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "rdf",
  uri: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "rdfs",
  uri: "http://www.w3.org/2000/01/rdf-schema#",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "dc",
  uri: "http://purl.org/dc/elements/1.1/",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "dcterms",
  uri: "http://purl.org/dc/terms/",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "foaf",
  uri: "http://xmlns.com/foaf/0.1/",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "skos",
  uri: "http://www.w3.org/2004/02/skos/core#",
  is_default: true
)
Namespace.find_or_create_by(
  prefix: "owl",
  uri: "http://www.w3.org/2002/07/owl#",
  is_default: true
)

# class_map_properties
ClassMapProperty.find_or_create_by(
  property: "d2rq:dataStorage",
  label: "Data storage",
  is_literal: false
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:class",
  label: "rdf:type",
  is_literal: false
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:uriPattern",
  label: "URI pattern",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:uriColumn",
  label: "URI column",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:uriSqlExpression",
  label: "URI SQL Expression",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:bNodeIdColumns",
  label: "Blank node",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:constantValue",
  label: "Constant value",
  is_literal: false
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:containsDuplicates",
  label: "Contains uplicates",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:additionalProperty",
  label: "Additional property",
  is_literal: false
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:condition",
  label: "Condition",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:classDefinitionLabel",
  label: "rdfs:label",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:classDefinitionComment",
  label: "rdfs:comment",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:additionalClassDefinitionProperty",
  label: "Additional class definition property",
  is_literal: false
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:valueMaxLength",
  label: "Max length of value",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:valueRegex",
  label: "Regular expression of value",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:valueContains",
  label: "Value contains",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:translateWith",
  label: "Translate with",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:join",
  label: "Join",
  is_literal: true
)
ClassMapProperty.find_or_create_by(
  property: "d2rq:alias",
  label: "Alias",
  is_literal: true
)

# property_bridge_properties
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:belongsToClassMap",
  label: "Belongs to class map",
  is_literal: false
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:property",
  label: "Property",
  is_literal: false
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:dynamicProperty",
  label: "Dynamic property",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:column",
  label: "Literal column",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:pattern",
  label: "Literal pattern",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:sqlExpression",
  label: "Literal SQL Expression",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:uriColumn",
  label: "URI column",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:uriPattern",
  label: "URI pattern",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:uriSqlExpression",
  label: "URI SQL Expression",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:constantValue",
  label: "Constant value",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:refersToClassMap",
  label: "Subject URI of object table record",
  is_literal: false
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:datatype",
  label: "Data type",
  is_literal: false
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:lang",
  label: "Lang",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:join",
  label: "Join",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:alias",
  label: "Alias",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:condition",
  label: "Condition",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:translateWith",
  label: "Translate with",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:valueMaxLength",
  label: "Max length of value",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:valueContains",
  label: "Value contains",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:valueRegex",
  label: "Regular expression of value",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:propertyDefinitionLabel",
  label: "rdfs:label",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:propertyDefinitionComment",
  label: "rdfs:comment",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:additionalPropertyDefinitionProperty",
  label: "Additional property definition property",
  is_literal: false
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:limit",
  label: "Limit",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:limitInverse",
  label: "Limit inverse",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:orderAsc",
  label: "Order asc",
  is_literal: true
)
PropertyBridgeProperty.find_or_create_by(
  property: "d2rq:orderDesc",
  label: "Order desc",
  is_literal: true
)

# property_bridge_types
PropertyBridgeType.find_or_create_by(
  symbol: "column"
)
PropertyBridgeType.find_or_create_by(
  symbol: "label"
)
PropertyBridgeType.find_or_create_by(
  symbol: "bnode"
)
PropertyBridgeType.find_or_create_by(
  symbol: "constant"
)
